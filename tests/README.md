# npm-docker.cmd Test Suite

This directory contains automated tests for `npm-docker.cmd` to verify its core functionality without requiring Docker to be installed.

## Test Framework Structure

```
tests/
├── README.md                    # This file
├── run-tests-simple.cmd         # Main test runner
├── mock-docker.cmd              # Mock Docker executable for testing
├── scenarios/                   # Test scenario directories
│   ├── 01-blank-project/
│   ├── 02-default-version/
│   ├── 03-nvmrc-custom-version/
│   ├── 04-port-mapping/
│   └── 05-nvmrc-with-ports/
```

## How It Works

1. **Test Mode**: When `.npm-docker-test` file exists in a directory, `npm-docker.cmd` outputs the Docker command instead of executing it
2. **Mock Docker**: A mock `docker.cmd` is added to PATH to handle Docker version/info checks without requiring actual Docker
3. **Test Scenarios**: Each scenario directory represents a real-world project setup with specific configurations
4. **Validation**: Tests capture output and verify expected patterns (Node version, port mappings, etc.)

## Running Tests

### Quick Start
```cmd
cd tests
run-tests-simple.cmd
```

### What Gets Tested

✅ **Test 01: Blank Project**
- Verifies default Node.js version (24) is used
- Tests basic command execution

✅ **Test 02: Version Command**  
- Confirms `npm -v` command is passed correctly

✅ **Test 03: Custom .nvmrc**
- Verifies `.nvmrc` file is read correctly
- Tests Node version switching (18)

✅ **Test 04: Port Mapping**
- Validates `.npm-docker-ports` file parsing
- Checks port mapping format (3000:3000)

✅ **Test 05: Combined Features**
- Tests `.nvmrc` (Node 20) + `.npm-docker-ports` (4000:4000)
- Ensures multiple features work together

## Test Scenarios Details

### Scenario 01: Blank Project
- **Files**: `.npm-docker-test`
- **Purpose**: Test default configuration
- **Expected**: `node:24-alpine`

### Scenario 02: Default Version
- **Files**: `.npm-docker-test`
- **Purpose**: Verify npm command pass-through
- **Expected**: Command includes `npm -v`

### Scenario 03: Custom .nvmrc Version
- **Files**: `.nvmrc` (contains "18"), `.npm-docker-test`
- **Purpose**: Test Node version detection from .nvmrc
- **Expected**: `node:18-alpine`

### Scenario 04: Port Mapping
- **Files**: `.npm-docker-ports` (contains "3000"), `.npm-docker-test`
- **Purpose**: Test port mapping configuration
- **Expected**: `-p 3000:3000` in command

### Scenario 05: Combined Features
- **Files**: `.nvmrc` (contains "20"), `.npm-docker-ports` (contains "4000:4000"), `.npm-docker-test`
- **Purpose**: Test multiple features working together
- **Expected**: `node:20-alpine` AND `-p 4000:4000`

## Known Issues

### Syntax Error in npm-docker.cmd
There is a known syntax error in the current version of `npm-docker.cmd` when processing port mappings:

**Error**: `is was unexpected at this time.`

**Location**: Port mapping section that uses `findstr` with delayed expansion

**Impact**: 
- Test 01 (blank project) works correctly
- Tests with port mapping configurations may fail
- Tests with .nvmrc-only configurations may work

**Workaround**: This issue would need to be fixed in `npm-docker.cmd` by adjusting the errorlevel handling in the port mapping section.

## Adding New Tests

To add a new test scenario:

1. Create a new directory under `scenarios/`:
   ```cmd
   mkdir tests\scenarios\06-my-new-test
   ```

2. Add necessary configuration files (`.nvmrc`, `.npm-docker-ports`, etc.)

3. Add the `.npm-docker-test` marker file:
   ```cmd
   echo # Test mode > tests\scenarios\06-my-new-test\.npm-docker-test
   ```

4. Add a new test block in `run-tests-simple.cmd`:
   ```batch
   set /a TOTAL+=1
   echo [TEST 06] My New Test
   pushd "%TESTS_DIR%scenarios\06-my-new-test"
   call "%NPM_DOCKER%" <command> 2>&1 | findstr /C:"expected-pattern" >nul
   if !errorlevel! equ 0 (
       echo [PASS] Test description
       set /a PASSED+=1
   ) else (
       echo [FAIL] Expected pattern not found
       set /a FAILED+=1
   )
   popd
   echo.
   ```

## Mock Docker

The `mock-docker.cmd` script simulates Docker commands without requiring Docker to be installed:

- **`docker version`**: Returns success
- **`docker info --format "{{.KernelVersion}}"`**: Returns "windows"
- **`docker network create`**: Returns success
- **`docker run`**: Should not be called in test mode (returns error)

## Test Output

Successful test run:
```
================================================================
npm-docker.cmd Test Suite (Simplified)
================================================================

Using mock Docker for testing

[TEST 01] Blank Project - Default Node 24
[PASS] Default Node version 24 detected
...
================================================================
Test Summary
================================================================
Total:  5
Passed: 5
Failed: 0
================================================================

[RESULT] All tests PASSED!
```

## Limitations

1. **No Docker Execution**: Tests verify command construction only, not actual Docker execution
2. **Syntax Dependency**: Tests depend on npm-docker.cmd's current implementation
3. **Windows Only**: Test scripts are Windows batch files (.cmd)
4. **Mock Limitations**: Mock Docker doesn't simulate all Docker behaviors

## Benefits

✅ Fast execution (no Docker containers)  
✅ No Docker installation required  
✅ Consistent test environment  
✅ Easy to add new test scenarios  
✅ Validates critical functionality

## Future Improvements

- Fix syntax errors in npm-docker.cmd
- Add tests for `.npm-docker-ignore` functionality
- Test WSL2 vs Windows Docker detection
- Add integration tests with real Docker
- Create tests for monorepo node_modules support

## Author

Created as part of the npm-docker.cmd testing infrastructure.
