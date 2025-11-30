@echo off
REM run-tests-simple.cmd
REM Simplified test runner that manually calls npm-docker in each scenario

setlocal ENABLEDELAYEDEXPANSION

echo ================================================================
echo npm-docker.cmd Test Suite (Simplified)
echo ================================================================
echo.

set "TESTS_DIR=%~dp0"
set "NPM_DOCKER=%TESTS_DIR%..\npm-docker.cmd"
set "PASSED=0"
set "FAILED=0"
set "TOTAL=0"

REM Setup mock docker in PATH
set "PATH=%TESTS_DIR%;%PATH%"
if exist "%TESTS_DIR%docker.cmd" del "%TESTS_DIR%docker.cmd" >nul 2>&1
copy "%TESTS_DIR%mock-docker.cmd" "%TESTS_DIR%docker.cmd" >nul 2>&1

echo Using mock Docker for testing
echo.

REM --- Test 01: Blank Project - Default version ---
set /a TOTAL+=1
echo [TEST 01] Blank Project - Default Node 24
pushd "%TESTS_DIR%scenarios\01-blank-project"
call "%NPM_DOCKER%" -v 2>&1 | findstr /C:"node:24-alpine" >nul
if !errorlevel! equ 0 (
    echo [PASS] Default Node version 24 detected
    set /a PASSED+=1
) else (
    echo [FAIL] Expected node:24-alpine
    call "%NPM_DOCKER%" -v
    set /a FAILED+=1
)
popd
echo.

REM --- Test 02: npm -v command ---
set /a TOTAL+=1
echo [TEST 02] npm -v command present
pushd "%TESTS_DIR%scenarios\02-default-version"
call "%NPM_DOCKER%" -v 2>&1 | findstr /C:"npm -v" >nul
if !errorlevel! equ 0 (
    echo [PASS] Command includes 'npm -v'
    set /a PASSED+=1
) else (
    echo [FAIL] Expected 'npm -v' in command
    call "%NPM_DOCKER%" -v
    set /a FAILED+=1
)
popd
echo.

REM --- Test 03: Custom .nvmrc version 18 ---
set /a TOTAL+=1
echo [TEST 03] Custom .nvmrc Node 18
pushd "%TESTS_DIR%scenarios\03-nvmrc-custom-version"
call "%NPM_DOCKER%" install 2>&1 | findstr /C:"node:18-alpine" >nul
if !errorlevel! equ 0 (
    echo [PASS] Node 18 from .nvmrc detected
    set /a PASSED+=1
) else (
    echo [FAIL] Expected node:18-alpine
    call "%NPM_DOCKER%" install
    set /a FAILED+=1
)
popd
echo.

REM --- Test 04: Port mapping 3000 ---
set /a TOTAL+=1
echo [TEST 04] Port mapping 3000:3000
pushd "%TESTS_DIR%scenarios\04-port-mapping"
call "%NPM_DOCKER%" run start 2>&1 | findstr /C:"-p 3000:3000" >nul
if !errorlevel! equ 0 (
    echo [PASS] Port 3000:3000 mapped
    set /a PASSED+=1
) else (
    echo [FAIL] Expected '-p 3000:3000'
    call "%NPM_DOCKER%" run start
    set /a FAILED+=1
)
popd
echo.

REM --- Test 05: Combined .nvmrc 20 + ports 4000 ---
set /a TOTAL+=1
echo [TEST 05] Node 20 + Port 4000:4000
pushd "%TESTS_DIR%scenarios\05-nvmrc-with-ports"
call "%NPM_DOCKER%" run dev 2>&1 > temp.txt
findstr /C:"node:20-alpine" temp.txt >nul
set "NODE20=!errorlevel!"
findstr /C:"-p 4000:4000" temp.txt >nul
set "PORT4000=!errorlevel!"
if !NODE20! equ 0 if !PORT4000! equ 0 (
    echo [PASS] Node 20 and Port 4000:4000 detected
    set /a PASSED+=1
) else (
    echo [FAIL] Expected node:20-alpine AND -p 4000:4000
    type temp.txt
    set /a FAILED+=1
)
del temp.txt >nul 2>&1
popd
echo.

REM --- Cleanup ---
if exist "%TESTS_DIR%docker.cmd" del "%TESTS_DIR%docker.cmd" >nul 2>&1

REM --- Summary ---
echo ================================================================
echo Test Summary
echo ================================================================
echo Total:  !TOTAL!
echo Passed: !PASSED!
echo Failed: !FAILED!
echo ================================================================

if !FAILED! gtr 0 (
    echo.
    echo [RESULT] Some tests FAILED
    exit /b 1
) else (
    echo.
    echo [RESULT] All tests PASSED!
    exit /b 0
)

endlocal
