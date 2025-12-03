#!/bin/bash
# run-tests.sh
# Test runner for npm-docker.sh
# Runs all test scenarios and reports results

echo "================================================================"
echo "npm-docker.sh Test Suite"
echo "================================================================"
echo

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NPM_DOCKER="$SCRIPT_DIR/../npm-docker.sh"
SCENARIOS_DIR="$SCRIPT_DIR/scenarios"
PASSED=0
FAILED=0
TOTAL=0

# Check if npm-docker.sh exists
if [ ! -f "$NPM_DOCKER" ]; then
    echo "[ERROR] npm-docker.sh not found at: $NPM_DOCKER"
    exit 1
fi

echo "Running tests from: $SCENARIOS_DIR"
echo

# --- Test 01: Blank Project ---
((TOTAL++))
echo "[TEST 01] Blank Project - Default version check"
cd "$SCENARIOS_DIR/01-blank-project"
bash "$NPM_DOCKER" -v > output.txt 2>&1
if grep -q "node:24-alpine" output.txt; then
    echo "[PASS] Found default Node version 24"
    ((PASSED++))
else
    echo "[FAIL] Expected node:24-alpine"
    echo "Output:"
    cat output.txt
    ((FAILED++))
fi
rm -f output.txt
echo

# --- Test 02: Default Version Command ---
((TOTAL++))
echo "[TEST 02] Version check shows npm -v"
cd "$SCENARIOS_DIR/02-default-version"
bash "$NPM_DOCKER" -v > output.txt 2>&1
if grep -q "npm --ignore-scripts -v" output.txt; then
    echo "[PASS] Command includes 'npm --ignore-scripts -v'"
    ((PASSED++))
else
    echo "[FAIL] Expected 'npm --ignore-scripts -v' in output"
    echo "Output:"
    cat output.txt
    ((FAILED++))
fi
rm -f output.txt
echo

# --- Test 03: Custom .nvmrc Version ---
((TOTAL++))
echo "[TEST 03] Custom .nvmrc version detection"
cd "$SCENARIOS_DIR/03-nvmrc-custom-version"
bash "$NPM_DOCKER" install > output.txt 2>&1
if grep -q "node:18-alpine" output.txt; then
    echo "[PASS] Detected Node version 18 from .nvmrc"
    ((PASSED++))
else
    echo "[FAIL] Expected node:18-alpine"
    echo "Output:"
    cat output.txt
    ((FAILED++))
fi
rm -f output.txt
echo

# --- Test 04: Port Mapping ---
((TOTAL++))
echo "[TEST 04] Port mapping from .npm-docker-ports"
cd "$SCENARIOS_DIR/04-port-mapping"
bash "$NPM_DOCKER" run start > output.txt 2>&1
if grep -q "\-p 3000:3000" output.txt; then
    echo "[PASS] Port mapping 3000:3000 detected"
    ((PASSED++))
else
    echo "[FAIL] Expected '-p 3000:3000' in output"
    echo "Output:"
    cat output.txt
    ((FAILED++))
fi
rm -f output.txt
echo

# --- Test 05: Combined .nvmrc + Ports ---
((TOTAL++))
echo "[TEST 05] Combined .nvmrc and port mapping"
cd "$SCENARIOS_DIR/05-nvmrc-with-ports"
bash "$NPM_DOCKER" run dev > output.txt 2>&1

# Check for Node version 20
if grep -q "node:20-alpine" output.txt; then
    NODE_CHECK=0
else
    NODE_CHECK=1
fi

# Check for port mapping
if grep -q "\-p 4000:4000" output.txt; then
    PORT_CHECK=0
else
    PORT_CHECK=1
fi

if [ $NODE_CHECK -eq 0 ] && [ $PORT_CHECK -eq 0 ]; then
    echo "[PASS] Node 20 and port 4000:4000 both detected"
    ((PASSED++))
else
    echo "[FAIL] Expected node:20-alpine AND -p 4000:4000"
    if [ $NODE_CHECK -ne 0 ]; then
        echo "  - Missing: node:20-alpine"
    fi
    if [ $PORT_CHECK -ne 0 ]; then
        echo "  - Missing: -p 4000:4000"
    fi
    echo "Output:"
    cat output.txt
    ((FAILED++))
fi

rm -f output.txt
echo

# --- Test 08: Monorepo Support ---
((TOTAL++))
echo "[TEST 08] Monorepo support with subdirectory"
cd "$SCENARIOS_DIR/08-monorepo-mounting/src/ui"
bash "$NPM_DOCKER" install > output.txt 2>&1
if grep -q '\-v "../../node_modules":"/app/node_modules"' output.txt; then
    echo "[PASS] Correct mount for monorepo subdirectory"
    ((PASSED++))
else
    echo "[FAIL] Expected mount for ../node_modules:/app/node_modules"
    echo "Output:"
    cat output.txt
    ((FAILED++))
fi

# Verify command output contains docker run --rm -it
((TOTAL++))
if grep -q "docker run --rm -it " output.txt; then
    echo "[PASS] Docker run command detected"
    ((PASSED++))
else
    echo "[FAIL] Docker run command not found"
    echo "Output:"
    cat output.txt
    ((FAILED++))
fi

rm -f output.txt
echo

echo "================================================================"
echo "Test Summary:"
echo "Total Tests: $TOTAL"
echo "Passed:      $PASSED"
echo "Failed:      $FAILED"
echo "================================================================"
