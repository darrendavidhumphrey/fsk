@echo off
setlocal enabledelayedexpansion

echo ==================================================
echo FSK Shader Rebuild Utility (AGGRESSIVE)
echo ==================================================

REM 1. Clean up ALL stale artifacts and build caches
echo [1/3] Clearing build caches...
if exist "build" (
    rmdir /s /q "build"
)
if exist "example\build" (
    rmdir /s /q "example\build"
)
if exist "shaders\fsk.shaderbundle" (
    del "shaders\fsk.shaderbundle"
)

REM 2. Trigger the Flutter Build Hook
echo [2/3] Triggering build hook via example project...
pushd example
call flutter build bundle
popd

REM 3. Verify results
echo [3/3] Verifying output...
if exist "example\build\flutter_assets\packages\fsk\flutter_gpu_shaders\shaderbundles\fsk.shaderbundle" (
    echo   - SUCCESS: Dynamic shader bundle has been regenerated.
    echo   - Bundle Path: example\build\flutter_assets\packages\fsk\flutter_gpu_shaders\shaderbundles\fsk.shaderbundle
) else (
    echo   - WARNING: Dynamic bundle not found. Check above for GLSL errors.
)

echo ==================================================
echo DONE.
echo ==================================================

