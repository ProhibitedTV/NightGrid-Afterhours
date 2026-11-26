@echo off
setlocal
pushd "%~dp0..\.."
wsl.exe -d Ubuntu --exec bash tools/asset_refinement/run_factory.sh %*
set "RC=%ERRORLEVEL%"
popd
exit /b %RC%
