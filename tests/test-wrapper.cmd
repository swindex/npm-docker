@echo off
REM test-wrapper.cmd
REM Wrapper to test npm-docker.cmd in isolation

setlocal ENABLEDELAYEDEXPANSION

set "SCENARIO_DIR=%~1"
set "NPM_DOCKER=%~2"
shift
shift

REM Collect all remaining arguments
set "ARGS="
:loop
if "%~1"=="" goto endloop
set "ARGS=!ARGS! %~1"
shift
goto loop
:endloop

REM Change to scenario directory
cd /d "%SCENARIO_DIR%"

REM Execute npm-docker.cmd
call "%NPM_DOCKER%" !ARGS!

endlocal
exit /b %errorlevel%
