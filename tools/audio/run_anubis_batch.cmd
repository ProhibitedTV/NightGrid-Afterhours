@echo off
setlocal
cd /d "%~dp0..\.."
set "ANUBIS_SOURCE_SHA="
for /f %%H in ('git rev-parse HEAD') do set "ANUBIS_SOURCE_SHA=%%H"
wsl.exe -d Ubuntu -u anubis --cd "%CD%" -- env "ANUBIS_SOURCE_SHA=%ANUBIS_SOURCE_SHA%" bash tools/audio/run_anubis_batch.sh %*
exit /b %ERRORLEVEL%
