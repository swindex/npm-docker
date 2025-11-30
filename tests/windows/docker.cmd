@echo off
REM mock-docker.cmd
REM Mock Docker command that outputs nothing for test scenarios

REM Handle different docker commands
if "%1"=="version" (
    exit /b 0
)

if "%1"=="info" (
    if "%2"=="--format" (
        echo windows
    )
    exit /b 0
)

if "%1"=="network" (
    exit /b 0
)

if "%1"=="run" (
    REM This shouldn't be called in test mode
    echo ERROR: Docker run should not be called in test mode
    exit /b 1
)

exit /b 0
