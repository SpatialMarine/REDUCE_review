@echo off
setlocal
set "TRACE_PY=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
if exist "%TRACE_PY%" (
  "%TRACE_PY%" "%~dp0serve.py"
) else (
  py -3 "%~dp0serve.py"
)
if errorlevel 1 pause
