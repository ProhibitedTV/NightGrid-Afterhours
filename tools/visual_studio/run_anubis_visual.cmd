@echo off
setlocal
pushd "%~dp0..\.."
wsl.exe --exec bash tools/visual_studio/run_anubis_visual.sh %*
set "RC=%ERRORLEVEL%"
popd
exit /b %RC%
