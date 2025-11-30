@echo off
REM run-tests.cmd
REM Test runner for npm-docker.cmd
REM Runs all test scenarios and reports results

setlocal ENABLEDELAYEDEXPANSION

echo ================================================================
echo npm-docker.cmd Test Suite
echo ================================================================
echo.

set "SCRIPT_DIR=%~dp0"
set "NPM_DOCKER=%SCRIPT_DIR%..\npm-docker.cmd"
set "SCENARIOS_DIR=%SCRIPT_DIR%scenarios"
set "PASSED=0"
set "FAILED=0"
set "TOTAL=0"

REM Check if npm-docker.cmd exists
if not exist "%NPM_DOCKER%" (
    echo [ERROR] npm-docker.cmd not found at: %NPM_DOCKER%
    exit /b 1
)

echo Running tests from: %SCENARIOS_DIR%
echo.

REM --- Test 01: Blank Project ---
set /a TOTAL+=1
echo [TEST 01] Blank Project - Default version check
cd /d "%SCENARIOS_DIR%\01-blank-project"
call "%NPM_DOCKER%" -v > output.txt 2>&1
findstr /C:"node:24-alpine" output.txt >nul 2>&1
if !errorlevel! equ 0 (
    echo [PASS] Found default Node version 24
    set /a PASSED+=1
) else (
    echo [FAIL] Expected node:24-alpine
    echo Output:
    type output.txt
    set /a FAILED+=1
)
del output.txt >nul 2>&1
echo.

REM --- Test 02: Default Version Command ---
set /a TOTAL+=1
echo [TEST 02] Version check shows npm -v
cd /d "%SCENARIOS_DIR%\02-default-version"
call "%NPM_DOCKER%" -v > output.txt 2>&1
findstr /C:"npm -v" output.txt >nul 2>&1
if !errorlevel! equ 0 (
    echo [PASS] Command includes 'npm -v'
    set /a PASSED+=1
) else (
    echo [FAIL] Expected 'npm -v' in output
    echo Output:
    type output.txt
    set /a FAILED+=1
)
del output.txt >nul 2>&1
echo.

REM --- Test 03: Custom .nvmrc Version ---
set /a TOTAL+=1
echo [TEST 03] Custom .nvmrc version detection
cd /d "%SCENARIOS_DIR%\03-nvmrc-custom-version"
call "%NPM_DOCKER%" install > output.txt 2>&1
findstr /C:"node:18-alpine" output.txt >nul 2>&1
if !errorlevel! equ 0 (
    echo [PASS] Detected Node version 18 from .nvmrc
    set /a PASSED+=1
) else (
    echo [FAIL] Expected node:18-alpine
    echo Output:
    type output.txt
    set /a FAILED+=1
)
del output.txt >nul 2>&1
echo.

REM --- Test 04: Port Mapping ---
set /a TOTAL+=1
echo [TEST 04] Port mapping from .npm-docker-ports
cd /d "%SCENARIOS_DIR%\04-port-mapping"
call "%NPM_DOCKER%" run start > output.txt 2>&1
findstr /C:"-p 3000:3000" output.txt >nul 2>&1
if !errorlevel! equ 0 (
    echo [PASS] Port mapping 3000:3000 detected
    set /a PASSED+=1
) else (
    echo [FAIL] Expected '-p 3000:3000' in output
    echo Output:
    type output.txt
    set /a FAILED+=1
)
del output.txt >nul 2>&1
echo.

REM --- Test 05: Combined .nvmrc + Ports ---
set /a TOTAL+=1
echo [TEST 05] Combined .nvmrc and port mapping
cd /d "%SCENARIOS_DIR%\05-nvmrc-with-ports"
call "%NPM_DOCKER%" run dev > output.txt 2>&1

REM Check for Node version 20
findstr /C:"node:20-alpine" output.txt >nul 2>&1
set "NODE_CHECK=!errorlevel!"

REM Check for port mapping
findstr /C:"-p 4000:4000" output.txt >nul 2>&1
set "PORT_CHECK=!errorlevel!"

if !NODE_CHECK! equ 0 if !PORT_CHECK! equ 0 (
    echo [PASS] Node 20 and port 4000:4000 both detected
    set /a PASSED+=1
) else (
    echo [FAIL] Expected node:20-alpine AND -p 4000:4000
    if !NODE_CHECK! neq 0 echo   - Missing: node:20-alpine
    if !PORT_CHECK! neq 0 echo   - Missing: -p 4000:4000
    echo Output:
    type output.txt
    set /a FAILED+=1
)

del output.txt >nul 2>&1
echo.

REM --- Test 06: Network Check - npm install (Normal Network) ---
set /a TOTAL+=1
echo [TEST 06] npm install uses normal network
cd /d "%SCENARIOS_DIR%\06-network-install"
call "%NPM_DOCKER%" install > output.txt 2>&1

REM Check that network flag is NOT present (normal network)
findstr /C:"--network lan_only" output.txt >nul 2>&1
set "HAS_LAN_ONLY=!errorlevel!"

findstr /I "Normal network enabled" output.txt >nul 2>&1
set "HAS_NORMAL_MSG=!errorlevel!"

if !HAS_LAN_ONLY! equ 0 (
    echo [FAIL] npm install should NOT use --network lan_only
    echo Output:
    type output.txt
    set /a FAILED+=1
) else (
    if !HAS_NORMAL_MSG! equ 0 (
        echo [PASS] npm install uses normal network (no --network flag^)
        set /a PASSED+=1
    ) else (
        echo [FAIL] Expected "Normal network enabled" message
        echo Output:
        type output.txt
        set /a FAILED+=1
    )
)
del output.txt >nul 2>&1
echo.

REM --- Test 07: Network Check - npm run (LAN-only Network) ---
set /a TOTAL+=1
echo [TEST 07] npm run uses LAN-only network
cd /d "%SCENARIOS_DIR%\07-network-run"
call "%NPM_DOCKER%" run start > output.txt 2>&1

REM Check that network flag IS present (LAN-only)
findstr /C:"--network lan_only" output.txt >nul 2>&1
if !errorlevel! equ 0 (
    echo [PASS] npm run uses --network lan_only
    set /a PASSED+=1
) else (
    echo [FAIL] Expected --network lan_only flag
    echo Output:
    type output.txt
    set /a FAILED+=1
)
del output.txt >nul 2>&1
echo.

REM --- Test 08: Monorepo Support ---
set /a TOTAL+=1
echo [TEST 08] Monorepo support with subdirectory
cd /d "%SCENARIOS_DIR%\08-monorepo-mounting\src\ui"
call "%NPM_DOCKER%" install
call "%NPM_DOCKER%" install > output.txt 2>&1
findstr /C:"-v \"../../node_modules\":\"/app/node_modules\"" output.txt >nul 2>&1
if !errorlevel! equ 0 (
    echo [PASS] Correct mount for monorepo subdirectory
    set /a PASSED+=1
) else (
    echo [FAIL] Expected mount for ../node_modules:/app/node_modules
    echo Output:
    type output.txt
    set /a FAILED+=1
)

REM Verify command output contains docker run --rm -it
set /a TOTAL+=1
findstr /C:"docker run --rm -it " output.txt >nul 2>&1 
if !errorlevel! equ 0 (
    echo [PASS] Docker run command detected
    set /a PASSED+=1
) else (
    echo [FAIL] Docker run command not found
    echo Output:
    type output.txt
    set /a FAILED+=1
)

del output.txt >nul 2>&1
echo.


echo ================================================================
echo Test Summary:
echo Total Tests: !TOTAL!
echo Passed:      !PASSED!
echo Failed:      !FAILED!
echo ================================================================
endlocal
