@echo off
setlocal
pushd "%~dp0..\.." || exit /b 2
wsl.exe -d Ubuntu -u root --cd "%CD%" -- bash tools/asset_refinement/anubis_operator.sh status %*
set "RC=%ERRORLEVEL%"
popd
exit /b %RC%
