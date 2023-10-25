@echo off
setlocal EnableDelayedExpansion

if "%PYTHON_VERSION%" == "" (
    echo "Missing PYTHON_VERSION variable"
    exit /b 1
)

if  "%PLATTAG%" == "" (
    echo "Missing PLATTAG variable"
    exit /b 1
)

set PYTAG=%PYTHON_VERSION:~0,1%%PYTHON_VERSION:~2,1%
set SPECARGS=--python-version %PYTHON_VERSION% --platform %PLATTAG% --pip-arg=-r --pip-arg=%ENVSPEC%

echo PYTAG    = %PYTAG%
echo SPECARGS = %SPECARGS%

rem Store/restore path around the build to not affect the tests later
set PATH_BEFORE_BUILD=%PATH%
set "PATH=%PYTHON%;%PYTHON%\Scripts;%PATH%"

python --version                     || exit /b !ERRORLEVEL!
python -m pip --version              || exit /b !ERRORLEVEL!

if not "%BUILD_DEPS%" == "" (
    python -m pip install %BUILD_DEPS%   || exit /b !ERRORLEVEL!
)
python -m pip list --format=freeze

if not "%BUILD_LOCAL%" == "" (
    rem # https://bugs.python.org/issue29943
    python -c "import sys; assert not sys.version_info[:3] == (3, 6, 1)" ^
        || exit /b !ERRORLEVEL!

    python -m pip wheel -w ../wheels --no-deps -vv . ^
        || exit /b !ERRORLEVEL!

    python -m pip wheel -w ../wheels --no-deps -vv https://github.com/Quasars/orange-spectroscopy/archive/refs/heads/dask.zip ^
	    || exit /b !ERRORLEVEL!

    cd ..
    cd orange3-survival-analysis

    python -m pip wheel -w ../wheels --no-deps -vv . ^
        || exit /b !ERRORLEVEL!
    for /f %%s in ( 'python setup.py --version' ) do (
        set "SURVIVAL_VERSION=%%s"
    ) || exit /b !ERRORLEVEL!
    echo SURVIVAL_VERSION = "%SURVIVAL_VERSION%"
    rem # hardcode survival version because it is not properly detected
    set "SURVIVAL_VERSION=0.5.2.dev16+gccb7070"

    cd ..
    cd orange3-single-cell

    python -m pip wheel -w ../wheels --no-deps -vv . ^
        || exit /b !ERRORLEVEL!
    for /f %%s in ( 'python setup.py --version' ) do (
        set "SC_VERSION=%%s"
    ) || exit /b !ERRORLEVEL!
    echo SC_VERSION = "%SC_VERSION%"
    rem # hardcode survival version because it is not properly detected
    set "SC_VERSION=1.5.1.dev26+g40341cd"

    cd ..
    cd orange3

    for /f %%s in ( 'python setup.py --version' ) do (
        set "VERSION=%%s"
    ) || exit /b !ERRORLEVEL!
) else (
    set "VERSION=%BUILD_COMMIT%"
)
python -m pip wheel -w ../wheels -f ../wheels orange3==%VERSION% ^
    orange-spectroscopy==0.6.11+dask ^
    orange3-survival-analysis==%SURVIVAL_VERSION% ^
    orange3-singlecell==%SC_VERSION% ^
    -r "%ENVSPEC%"

echo VERSION  = "%VERSION%"

rem add msys2 and NSIS to path
set "PATH=C:\msys64\usr\bin;C:\Program Files (x86)\NSIS;%PATH%"
rem ensure unzip is present in msys2
bash -c "pacman -S --noconfirm unzip"  || exit /b %ERRORLEVEL%
bash -c "which unzip"                  || exit /b %ERRORLEVEL%
bash -e ../scripts/windows/build-win-installer.sh ^
     --find-links=../wheels ^
     --pip-arg=orange3==%VERSION% ^
     --pip-arg=orange-spectroscopy==0.6.11+dask ^
     --pip-arg=orange3-survival-analysis==%SURVIVAL_VERSION% ^
     --pip-arg=orange3-singlecell==%SC_VERSION% ^
     %SPECARGS%        || exit /b %ERRORLEVEL%

for %%s in ( dist/Orange3-*-Python*-*.exe ) do (
    set "INSTALLER=%%s"
)
for /f %%s in ( 'sha256sum -b dist/%INSTALLER%' ) do (
    set "CHECKSUM=%%s"
)

echo INSTALLER = %INSTALLER%
echo SHA256    = %CHECKSUM%

rem restore original path
set "PATH=%PATH_BEFORE_BUILD%"

@echo on
