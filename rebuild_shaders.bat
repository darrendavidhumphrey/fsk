@echo off
setlocal enabledelayedexpansion

echo ==================================================
echo FSK Shader Rebuild Utility
echo ==================================================

REM 1. Clean up stale artifacts
echo [1/3] Removing old shader bundle...
if exist "shaders\fsk.shaderbundle" (
    del "shaders\fsk.shaderbundle"
    echo   - Deleted shaders\fsk.shaderbundle
)

REM 2. Trigger the Flutter Build Hook
echo [2/3] Triggering build hook via example project...
echo This will compile all .vert and .frag files using the manifest.

pushd example
call flutter build bundle
popd

REM 3. Verify results
echo [3/3] Verifying output...
REM Note: The bundle is now correctly produced in the ephemeral build directory by the hook.
if exist "example\build\flutter_assets\packages\fsk\flutter_gpu_shaders\shaderbundles\fsk.shaderbundle" (
    echo   - SUCCESS: Dynamic shader bundle has been generated.
) else (
    echo   - WARNING: Dynamic bundle not found in expected build path.
    echo     This usually happens if the build above failed.
)

echo ==================================================
echo DONE.
echo ==================================================
pause
