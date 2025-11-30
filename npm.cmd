@echo off
REM npm-docker.cmd
REM Run npm commands inside Docker for isolation.
REM Created by Eldar Gerfanov. License: MIT.
REM Place this script in C:\proxy-scripts\ and add to PATH.
REM Optionally rename to npm.cmd to replace host npm. Make sure it's first in PATH.
REM Local npm installation is not required. In fact it is much safer if it's not installed!
REM Requires Docker to be installed and running.
REM For more help, run without arguments.

setlocal ENABLEDELAYEDEXPANSION

REM --- Configuration ---
set "NODE_MAJOR=24"
set "BLOCKFILE=.npm-docker-ignore"
set "PORTSFILE=.npm-docker-ports"
set "NODEVERSIONFILE=.nvmrc"

REM If this file exists, the docker command will be echoed instead of executed.
set "TESTFILE=.npm-docker-test"  

REM --- Help if no args---
if "%~1"=="" (
    echo -----------------------------------------------------------------
    echo npm-docker Sandbox. Run npm commands inside Docker for isolation.
    echo -----------------------------------------------------------------
    echo.
    echo Usage: %~n0 ^<npm command and arguments^>
    echo.
    echo Examples:
    echo   %~n0 -v
    echo   %~n0 install
    echo   %~n0 run build
    echo.
    echo This runs npm inside Docker with project files mounted,
    echo excluding any files listed in .npm-docker-ignore,
    echo and mapping ports listed in .npm-docker-ports.
    echo.
    echo Requirements:
    echo - Docker must be installed and running.
    echo - Local npm installation is not required!
    echo.
    echo Installation:
    echo - Place the npm-docker.cmd into C:\proxy-scripts\ and add it to your PATH.
    echo - Make sure to put it first in PATH.
    echo - Optionally, rename it to npm.cmd to replace host npm.
    echo   It allows this script to become almost a drop-in replacement for npm.
    echo   The only difference is that it runs inside Docker and requires .npm-docker-ports for port mapping if you plan to serve apps.
    echo.
    echo Node version:
    echo - By default, Node.js %NODE_MAJOR% (node:%NODE_MAJOR%-alpine) is used inside the Docker container.
    echo - To specify a different Node.js version, create a .nvmrc file in the project root
    echo   with the desired version number (e.g., "18.6.5" for Node.js 18.x). Only the major version is considered.
    echo.
    echo Port Mapping:
    echo - By default, no ports are mapped from the Docker container to the host.
    echo   So to serve applications from inside the Docker container and access them from the host,
    echo   create a file named %PORTSFILE% in the project root.
    echo - List one port mapping per line in the format hostport:containerport or just containerport to map the same port on host and container.
    echo - Lines starting with # are treated as comments and ignored.
    echo - Examples:
    echo     4200:4200
    echo     3000
    echo.
    echo Ignore Files:
    echo - To exclude files or directories from being mounted into the Docker container, create a file named .npm-docker-ignore in the project root.
    echo - List one file or directory name per line to exclude it from mounting.
    echo - Lines starting with # are treated as comments and ignored.
    echo - Examples:
    echo     .env
    echo     .super-secret-folder
    echo.
    echo Notes:
    echo - This script mounts the root of the current project, excluding any first-level files or directories listed in .npm-docker-ignore.
    echo   Since docker does not have native support for excluding files from mounts, the script accomplishes this by mounting empty files or directories over the excluded paths.
    echo.
    echo Created by: Eldar Gerfanov.
    echo License: MIT.
    echo This script is given as is without warranty of any kind. Use at your own risk.
    echo Although it should protect your host system from executing malicious npm scripts,
    echo    it is still possible to escape the container or even deploy malicious code on the server!
    echo.
    echo Script located in %~dp0
    echo.
    echo Now running...
)

REM --- Initialize ---
set "MOUNTS="
set "PORTS="
set "WIN_NPM_CACHE=%LOCALAPPDATA%/npm-cache"
set "WIN_MASKDIR=%TEMP%/npm-docker-mask"

REM ---- Node version detection from .nvmrc ----
if exist "%NODEVERSIONFILE%" (
	echo %NODEVERSIONFILE% file detected.
    for /f "delims=. tokens=1" %%V in ('type "%NODEVERSIONFILE%"') do (
        set "NODE_MAJOR=%%V"
    )
	echo Using node version !NODE_MAJOR!

    if defined NODE_MAJOR (
        echo Detected .nvmrc: Node major version !NODE_MAJOR!
        set "IMAGE=node:!NODE_MAJOR!-alpine"
    )
)

set "IMAGE=node:!NODE_MAJOR!-alpine"

REM ---- End Node version detection ----

REM ---- Docker availability check ----
call docker version >nul 2>&1
if errorlevel 1 (
    echo Docker not found or not running.
    exit /b 1
)
REM ---- End docker check ----

REM --- Ensure Windows npm cache directory exists ---
if not exist "%WIN_NPM_CACHE%" (
    echo Creating npm cache directory at "%WIN_NPM_CACHE%"
    mkdir "%WIN_NPM_CACHE%"
)
REM --- Mount npm cache ---

REM --- Check if docker is installed in windows or wsl2 an mount appropriately ---
for /f "delims=" %%K in ('docker info --format "{{.KernelVersion}}"') do set "KERNEL=%%K"
echo %KERNEL% | findstr /I "microsoft" >nul
if %errorlevel%==0 (
    echo Running npm in WSL2 Docker
    REM get wslpath of appdata dir
    for /f "delims=" %%P in ('wsl wslpath "%WIN_NPM_CACHE%"') do set "LINUX_WIN_NPM_CACHE=%%P"
    for /f "delims=" %%P in ('wsl wslpath "%WIN_MASKDIR%"') do set "MASKDIR=%%P"
    set "MOUNTS=!MOUNTS! -v "!LINUX_WIN_NPM_CACHE!":"/root/.npm""
) else (
    echo Running npm in Windows Docker
    set "MASKDIR=!WIN_MASKDIR!"
    set "MOUNTS=!MOUNTS! -v "%WIN_NPM_CACHE%":"/root/.npm""
)

REM --- Base: mount whole project ---
set "MOUNTS=!MOUNTS! -v ./:/app"

REM --- Hoisted / shared node_modules support (monorepo) ---
REM If node_modules lives in the parent folder, mount it into /app/node_modules
if exist "..\node_modules" (
    set "MOUNTS=!MOUNTS! -v "../node_modules":/app/node_modules"
)
if exist "..\..\node_modules" (
    set "MOUNTS=!MOUNTS! -v "../../node_modules":/app/node_modules"
)
if exist "..\..\..\node_modules" (
    set "MOUNTS=!MOUNTS! -v "../../../node_modules":/app/node_modules"
)
if exist "..\..\..\..\node_modules" (
    set "MOUNTS=!MOUNTS! -v "../../../../node_modules":/app/node_modules"
)
REM --- End hoisted node_modules support ---

REM --- Apply masks for blocklisted files/directories ---
if exist "%BLOCKFILE%" (
    echo Using ignore list: %BLOCKFILE%
    REM Ensure mask dir and file exist
    if not exist "%WIN_MASKDIR%" (
        mkdir "%WIN_MASKDIR%"
    )
    if not exist "%WIN_MASKDIR%/dummyfile" (
        copy /y nul "%WIN_MASKDIR%/dummyfile" >nul
    )
    for /f "usebackq tokens=* delims=" %%A in ("%BLOCKFILE%") do (
        set "LINE=%%A"
        if not "!LINE!"=="" if not "!LINE:~0,1!"=="#" (
            if exist "!LINE!" (
                REM If it is a file — mask with empty file
                if exist "!LINE!\*" (
                    REM It's a DIR — mask with empty dir
                    set "MOUNTS=!MOUNTS! -v "!MASKDIR!":"/app/!LINE!""
                ) else (
                    REM It's a FILE — create dummy empty file in maskdir
                    set "MOUNTS=!MOUNTS! -v "!MASKDIR!/dummyfile":"/app/!LINE!""
                )
            )
        )
    )
)
REM --- Map ports. Can be specified as "hostport:containerport" or just "port" (maps same:same) ---
if exist "%PORTSFILE%" (
    echo Using ports list: %PORTSFILE%
    for /f "usebackq tokens=* delims=" %%A in ("%PORTSFILE%") do (
        set "LINE=%%A"
        if not "!LINE!"=="" if not "!LINE:~0,1!"=="#" (
            REM If line contains colon, pass directly. Otherwise, map same:same
            echo !LINE! | findstr ":" >nul
            if !errorlevel! equ 0 (
                set "PORTS=!PORTS! -p !LINE!"
            ) else (
                set "PORTS=!PORTS! -p !LINE!:!LINE!"
            )
        )
    )
)

REM --- Create LAN-only network ---
docker network create --subnet=172.28.0.0/16 --gateway=172.28.0.1 --internal lan_only >nul 2>&1

REM --- Determine if the npm command requires internet access ---
echo %* | findstr /I "install update upgrade ci audit fund" >nul
if %errorlevel%==0 (
    echo Normal network enabled for npm %1
    set "NET="
) else (
    echo Using LAN-only network: WAN disabled
    set "NET=--network lan_only"
)

REM --- Uncomment to debug mounts and ports ---

if exist "%TESTFILE%" (
REM --- Echo the docker command instead of executing ---
    echo docker run --rm -it %NET% %MOUNTS% %PORTS% -w /app %IMAGE% npm %*
) else (
REM --- Execute the docker command ---
    docker run --rm -it %NET% %MOUNTS% %PORTS% -w /app %IMAGE% npm %*
)

endlocal