@echo on
setlocal EnableDelayedExpansion

if "%PYTHON_VERSION%" == "" (
    echo PYTHON_VERSION must be defined >&2
    exit /b 1
)

if  "%PLATTAG%" == "" (
    echo Missing PLATTAG variable >&2
    exit /b 1
)

rem activate the root conda environment (miniconda3 4.7.0 installs
rem libarchive that requires this - conda cannot be used as a executable
rem without activation first)
if exist "%CONDA%\..\activate" (
    call "%CONDA%\..\activate"
)

rem
rem call trubar
rem

cd ..

pip install trubar
set PYTHONUTF8=1

xcopy orange3 orange3-orig\ /s
xcopy orange-canvas-core orange-canvas-core-orig\ /s
xcopy orange-widget-base orange-widget-base-orig\ /s
trubar translate -s orange-canvas-core-orig/orangecanvas -d orange-canvas-core/orangecanvas --static orange-translations/si/orange-canvas-static orange-translations/si/orange-canvas-core.yaml
trubar translate -s orange-widget-base-orig/orangewidget -d orange-widget-base/orangewidget orange-translations/si/orange-widget-base.yaml
trubar translate -s orange3-orig/Orange -d orange3/Orange orange-translations/si/orange3.jaml
trubar --conf orange-translations/si/test_config.yaml translate -p test_ -s orange3-orig/Orange -d orange3/Orange orange-translations/si/orange3-tests.jaml

xcopy orange3-geo orange3-geo-orig\ /s
trubar translate -s orange3-geo-orig/orangecontrib/geo -d orange3-geo/orangecontrib/geo orange-translations/si/orange3-geo.jaml


cd orange3

copy ..\specs\meta.yaml conda-recipe\meta.yaml

"%CONDA%" config --append channels conda-forge  || exit /b !ERRORLEVEL!

if not "%CONDA_USE_ONLY_TAR_BZ2%" == "" (
    "%CONDA%" config --set use_only_tar_bz2 True  || exit /b !ERRORLEVEL!
    "%CONDA%" clean --all --yes
)

if "%CONDA_BUILD_VERSION%" == "" (
    set "CONDA_BUILD_VERSION=3.17.8"
)

if "%MINICONDA_VERSION%" == "" (
    set "MINICONDA_VERSION=4.7.12"
)

if not "%BUILD_LOCAL%" == "" (
    "%CONDA%" install --yes conda-build=%CONDA_BUILD_VERSION%  || exit /b !ERRORLEVEL!
    "%CONDA%" install --yes git
    "%CONDA%" build --no-test --python %PYTHON_VERSION% conda-recipe ^
        || exit /b !ERRORLEVEL!

    rem # Copy the build conda pkg to artifacts dir
    rem # and the cache\conda-pkgs which is used later by build-conda-installer
    rem # script

    mkdir ..\conda-pkgs        || exit /b !ERRORLEVEL!
    mkdir ..\cache             || exit /b !ERRORLEVEL!
    mkdir ..\cache\conda-pkgs  || exit /b !ERRORLEVEL!

    for /f %%s in ( '"%CONDA%" build --output --python %PYTHON_VERSION% ../specs/conda-recipe' ) do (
        copy /Y "%%s" ..\conda-pkgs\  || exit /b !ERRORLEVEL!
        copy /Y "%%s" ..\cache\conda-pkgs\  || exit /b !ERRORLEVEL!
    )

    for /f %%s in ( '"%PYTHON%" setup.py --version' ) do (
        set "VERSION=%%s"
    )
) else (
    set "VERSION=%BUILD_COMMIT%"
)

echo VERSION = %VERSION%

rem
rem build custom canvas and widget base
rem

cd ..\orange-canvas-core
mkdir recipe
copy ..\specs\recipe-canvas.yaml recipe\meta.yaml

"%CONDA%" build --no-test recipe ^
    || exit /b !ERRORLEVEL!

for /f %%s in ( '"%PYTHON%" setup.py --version' ) do (
    set "CANVAS-VERSION=%%s"
)

echo CANVAS-VERSION = %CANVAS-VERSION%

cd ..\orange-widget-base
mkdir recipe
copy ..\specs\recipe-widget.yaml recipe\meta.yaml

"%CONDA%" build --no-test recipe ^
    || exit /b !ERRORLEVEL!

for /f %%s in ( '"%PYTHON%" setup.py --version' ) do (
    set "WIDGET-VERSION=%%s"
)

echo WIDGET-VERSION = %WIDGET-VERSION%


cd ..\orange3-geo
mkdir recipe
copy ..\specs\recipe-geo.yaml recipe\meta.yaml

"%CONDA%" build --no-test recipe ^
    || exit /b !ERRORLEVEL!

for /f %%s in ( '"%PYTHON%" setup.py --version' ) do (
    set "GEO-VERSION=%%s"
)

echo GEO-VERSION = %GEO-VERSION%



cd ..\orange3

if "%CONDA_SPEC_FILE%" == "" (
    rem # prefer conda forge
    "%CONDA%" config --add channels conda-forge  || exit /b !ERRORLEVEL!
    "%CONDA%" config --set channel_priority strict

    "%CONDA%" create -n env --yes --use-local ^
                 python=%PYTHON_VERSION% ^
                 numpy=1.23.* ^
                 scipy=1.9.* ^
                 scikit-learn=1.1.* ^
                 pandas=1.4.* ^
                 pyqtgraph=0.13.* ^
                 bottleneck=1.3.* ^
                 pyqt=5.15.* ^
                 pyqtwebengine=5.15.* ^
                 Orange3=%VERSION% ^
                 orange-canvas-core=%CANVAS-VERSION% ^
                 orange-widget-base=%WIDGET-VERSION% ^
                 orange3-geo=%GEO-VERSION% ^
                 blas=*=openblas ^
        || exit /b !ERRORLEVEL!

    "%CONDA%" list -n env --export --explicit --md5 > env-spec.txt
    set CONDA_SPEC_FILE=env-spec.txt
)

type "%CONDA_SPEC_FILE%"

bash -e ../scripts/windows/build-conda-installer.sh ^
        --platform %PLATTAG% ^
        --cache-dir ../.cache ^
        --dist-dir dist ^
        --miniconda-version "%MINICONDA_VERSION%" ^
        --env-spec "%CONDA_SPEC_FILE%" ^
        --online no ^
    || exit /b !ERRORLEVEL!


for %%s in ( dist/Orange3-*Miniconda*.exe ) do (
    set "INSTALLER=%%s"
)

for /f %%s in ( 'sha256sum -b dist/%INSTALLER%' ) do (
    set "CHECKSUM=%%s"
)

echo INSTALLER = %INSTALLER%
echo SHA256    = %CHECKSUM%

@echo on
