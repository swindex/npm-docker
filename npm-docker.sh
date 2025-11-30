#!/bin/bash
# npm-docker.sh
# Run npm commands inside Docker for isolation.
# Created by Eldar Gerfanov. License: MIT.
# Place this script in /usr/local/bin/ and make it executable with: chmod +x npm-docker.sh
# Optionally create a symlink named npm to replace host npm.
# Local npm installation is not required. In fact it is much safer if it's not installed!
# Requires Docker to be installed and running.
# For more help, run npm-docker.sh without arguments.

# --- Configuration ---
NODE_MAJOR="24"
BLOCKFILE=".npm-docker-ignore"
PORTSFILE=".npm-docker-ports"
NODEVERSIONFILE=".nvmrc"
WAN_ENABLED=0   # By default, disable WAN for safety. Set to 1 to enable by default when local network isolation is not working properly.

# If this file exists, the docker command will be echoed instead of executed.
TESTFILE=".npm-docker-test"

# --- Help if no args---
if [ $# -eq 0 ]; then
    cat << 'EOF'
-----------------------------------------------------------------
npm-docker Sandbox. Run npm commands inside Docker for isolation.
-----------------------------------------------------------------

Usage: npm-docker.sh <npm command and arguments>

Examples:
  npm-docker.sh -v
  npm-docker.sh install
  npm-docker.sh run build

This runs npm inside Docker with project files mounted,
excluding any files listed in .npm-docker-ignore,
and mapping ports listed in .npm-docker-ports.

Requirements:
- Docker must be installed and running.
- Local npm installation is not required!

Installation:
- Place the npm-docker.sh into /usr/local/bin/ and make it executable (chmod +x npm-docker.sh).
  > sudo cp npm-docker.sh /usr/local/bin/npm-docker.sh
  > sudo chmod +x /usr/local/bin/npm-docker.sh
- Optionally, create a symlink named npm to replace host npm:
  > sudo ln -s /usr/local/bin/npm-docker.sh /usr/local/bin/npm
  Make sure /usr/local/bin is early in your PATH.
  It allows this script to become almost a drop-in replacement for npm.
  The only difference is that it runs inside Docker and requires .npm-docker-ports for port mapping if you plan to serve apps.

Node version:
- By default, Node.js 24 (node:24-alpine) is used inside the Docker container.
- To specify a different Node.js version, create a .nvmrc file in the project root
  with the desired version number e.g., "18.6.5" for Node.js 18.x. Only the major version is considered.

Port Mapping:
- By default, no ports are mapped from the Docker container to the host.
  So to serve applications from inside the Docker container and access them from the host,
  create a file named .npm-docker-ports in the project root.
- List one port mapping per line in the format hostport:containerport or just containerport to map the same port on host and container.
- Lines starting with # are treated as comments and ignored.
- Examples:
    4200:4200
    3000

Ignore Files:
- To exclude files or directories from being mounted into the Docker container, create a file named .npm-docker-ignore in the project root.
- List one file or directory name per line to exclude it from mounting.
- Lines starting with # are treated as comments and ignored.
- Examples:
    .env
    .super-secret-folder

Notes:
- This script mounts the root of the current project, excluding any first-level files or directories listed in .npm-docker-ignore.
  Since docker does not have native support for excluding files from mounts, the script accomplishes this by mounting empty files or directories over the excluded paths.

Created by: Eldar Gerfanov.
License: MIT.
This script is given "as is" without warranty of any kind. Use at your own risk.
Although it should protect your host system from executing malicious npm scripts,
   it is still possible to escape the container or even deploy malicious code on the server!
EOF
echo "Script located in $0"
echo "Now running..."
fi

# --- Initialize ---
MOUNTS=""
PORTS=""
NPM_CACHE="${HOME}/.npm-cache"
MASKDIR="/tmp/npm-docker-mask"

if [ -f "$TESTFILE" ]; then
    TESTMODE=1
else
    TESTMODE=0
fi

# ---- Node version detection from .nvmrc ----
if [ -f "$NODEVERSIONFILE" ]; then
    NODE_VERSION=$(head -n 1 "$NODEVERSIONFILE")
    NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
    # trim string from any return or EOF chars
    NODE_MAJOR=${NODE_MAJOR//$'\r'/}   # remove carriage return only
    echo "Detected .nvmrc: Node major version $NODE_MAJOR"
fi
IMAGE="node:${NODE_MAJOR}-alpine"
# ---- End Node version detection ----

# ---- Docker availability check ----
if [ "$TESTMODE" -eq 0 ]; then
    if ! docker version >/dev/null 2>&1; then
        echo "Docker not found or not running."
        exit 1
    fi
fi
# ---- End docker check ----

# --- Ensure npm cache directory exists ---
if [ ! -d "$NPM_CACHE" ]; then
    echo "Creating npm cache directory at $NPM_CACHE"
    mkdir -p "$NPM_CACHE"
fi

# --- Mount npm cache ---
MOUNTS="$MOUNTS -v \"$NPM_CACHE\":\"/root/.npm\""

# --- Base: mount whole project ---
MOUNTS="$MOUNTS -v ./:/app"

# --- Hoisted / shared node_modules support (monorepo) ---
# If node_modules lives in the parent folder, mount it into /app/node_modules
if [ -d "../node_modules" ]; then
    MOUNTS="$MOUNTS -v \"../node_modules\":\"/app/node_modules\""
fi
if [ -d "../../node_modules" ]; then
    MOUNTS="$MOUNTS -v \"../../node_modules\":\"/app/node_modules\""
fi
if [ -d "../../../node_modules" ]; then
    MOUNTS="$MOUNTS -v \"../../../node_modules\":\"/app/node_modules\""
fi
if [ -d "../../../../node_modules" ]; then
    MOUNTS="$MOUNTS -v \"../../../../node_modules\":\"/app/node_modules\""
fi
if [ -d "../../../../../node_modules" ]; then
    MOUNTS="$MOUNTS -v \"../../../../../node_modules\":\"/app/node_modules\""
fi
# --- End hoisted node_modules support ---

# --- Apply masks for blocklisted files/directories ---
if [ -f "$BLOCKFILE" ]; then
    echo "Using ignore list: $BLOCKFILE"
    # Ensure mask dir and file exist
    if [ ! -d "$MASKDIR" ]; then
        mkdir -p "$MASKDIR"
    fi
    if [ ! -f "$MASKDIR/dummyfile" ]; then
        touch "$MASKDIR/dummyfile"
    fi
    
    while IFS= read -r LINE; do
        # trim LINE string from any return or EOF chars
        LINE=${LINE//$'\r'/}   # remove carriage return only
        # Skip empty lines and comments
        if [ -n "$LINE" ] && [ "${LINE:0:1}" != "#" ]; then
            if [ -e "$LINE" ]; then
                # If it is a directory — mask with empty dir
                if [ -d "$LINE" ]; then
                    MOUNTS="$MOUNTS -v \"$MASKDIR\":\"/app/$LINE\""
                else
                    # It's a FILE — mount dummy empty file
                    MOUNTS="$MOUNTS -v \"$MASKDIR/dummyfile\":\"/app/$LINE\""
                fi
            fi
        fi
    done < "$BLOCKFILE"
fi

# --- Map ports. Can be specified as "hostport:containerport" or just "port" (maps same:same) ---
if [ -f "$PORTSFILE" ]; then
    echo "Using ports list: $PORTSFILE"
    while IFS= read -r LINE || [ -n "$LINE" ]; do
        LINE=${LINE//$'\r'/}   # remove carriage return only
        if [ -n "$LINE" ] && [ "${LINE:0:1}" != "#" ]; then
            if [[ "$LINE" == *:* ]]; then
                PORTS="$PORTS -p $LINE"
            else
                PORTS="$PORTS -p $LINE:$LINE"
            fi
        fi
    done < "$PORTSFILE"
fi

if [ "$WAN_ENABLED" -eq 0 ]; then
    # --- Create LAN-only network ---
    if [ "$TESTMODE" -eq 0 ]; then
        docker network create --driver bridge --internal lan_only >/dev/null 2>&1
    fi

    # --- Determine if the npm command requires internet access ---
    if echo "$*" | grep -qiE "install|update|upgrade|ci|audit|fund"; then
        echo "Normal network enabled for npm $1"
        NET=""
    else
        echo "Using LAN-only network: WAN disabled"
        NET="--network lan_only"
    fi
else
    echo "WAN access enabled."
    NET=""
fi

# --- Execute or echo the docker command ---
if [ "$TESTMODE" -eq 1 ]; then
    # --- Echo the docker command instead of executing ---
    echo "docker run --rm -it $NET $MOUNTS $PORTS -w /app $IMAGE npm $*"
else
    echo "docker run --rm -it $NET $MOUNTS $PORTS -w /app $IMAGE npm $*"
    # --- Execute the docker command ---
    eval docker run --rm -it $NET $MOUNTS $PORTS -w /app $IMAGE npm "$@"
    # clear keyboard interrupt signal to avoid issues in some environments
    trap '' INT
fi
