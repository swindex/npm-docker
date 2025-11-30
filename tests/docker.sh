#!/bin/bash
# mock-docker.sh
# Mock Docker command that outputs nothing for test scenarios

# Handle different docker commands
if [ "$1" = "version" ]; then
    exit 0
fi

if [ "$1" = "info" ]; then
    if [ "$2" = "--format" ]; then
        echo "linux"
    fi
    exit 0
fi

if [ "$1" = "network" ]; then
    exit 0
fi

if [ "$1" = "run" ]; then
    # This shouldn't be called in test mode
    echo "ERROR: Docker run should not be called in test mode"
    exit 1
fi

exit 0
