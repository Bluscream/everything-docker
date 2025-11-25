#!/bin/sh
export HOME=/config
export WINEDEBUG=-fixme-all

# Set Wine prefix to /config/.wine (subdirectory of /config mount, not a nested mount)
export WINEPREFIX="/config/.wine"

# Additional Wine environment variables to prevent deadlocks
export WINEDLLOVERRIDES="mscoree,mshtml="
export WINE_NO_ASYNC_DIRECTORY=1

# Note: Architecture is fixed at build time (via Dockerfile), so Wine config
# will always match the container's architecture. No need to check/remove it.

# Check if wine is available
if ! command -v wine >/dev/null 2>&1; then
    echo "Error: wine is not installed or not in PATH"
    exit 1
fi

# Set default binary if not specified
EVERYTHING_BINARY="${EVERYTHING_BINARY:-everything-1.5.exe}"
EVERYTHING_PATH="/opt/everything/${EVERYTHING_BINARY}"

# Check if the specified binary exists
if [ ! -f "$EVERYTHING_PATH" ]; then
    echo "Error: Everything binary not found at $EVERYTHING_PATH"
    echo "Available executables:"
    ls -1 /opt/everything/*.exe 2>/dev/null | sed 's|/opt/everything/|  - |' || echo "  (none found)"
    exit 1
fi

# WINEARCH is already set in the Dockerfile (win64 for amd64, win32 for i386)
# No need to detect architecture at runtime - trust the build-time setting
# Ensure WINEARCH is set (fallback for safety, though it should always be set)
export WINEARCH="${WINEARCH:-win64}"

# Initialize Wine prefix if it doesn't exist (only on first run)
if [ ! -d "/config/.wine" ]; then
    echo "Initializing Wine prefix..."
    wineboot --init 2>/dev/null || true
    
    # Wait a moment for Wine to fully initialize
    sleep 2
fi

# Apply registry tweaks to prevent deadlocks and COM marshalling issues
# Apply these on every startup to ensure they're always set
# Only apply if Wine prefix exists and is accessible
if [ -d "/config/.wine" ] && [ -f "/config/.wine/system.reg" ]; then
    echo "Applying Wine registry tweaks to prevent deadlocks..."
    
    # Ensure registry keys exist
    wine reg add "HKCU\\Software\\Wine" /f >/dev/null 2>&1 || true
    wine reg add "HKCU\\Software\\Wine\\DllOverrides" /f >/dev/null 2>&1 || true
    wine reg add "HKCU\\Software\\Wine\\Debug" /f >/dev/null 2>&1 || true
    wine reg add "HKCU\\Software\\Wine\\FileSystem" /f >/dev/null 2>&1 || true
    
    # Disable COM marshalling for problematic interfaces (fixes OLE errors)
    wine reg add "HKCU\\Software\\Wine\\DllOverrides" /v "ole32" /t REG_SZ /d "builtin" /f >/dev/null 2>&1 || true
    wine reg add "HKCU\\Software\\Wine\\DllOverrides" /v "oleaut32" /t REG_SZ /d "builtin" /f >/dev/null 2>&1 || true
    
    # Set file system options to prevent directory access deadlocks
    # wine reg add "HKCU\\Software\\Wine\\FileSystem" /v "ReadOnly" /t REG_SZ /d "N" /f >/dev/null 2>&1 || true
    # wine reg add "HKCU\\Software\\Wine\\FileSystem" /v "UseDType" /t REG_SZ /d "N" /f >/dev/null 2>&1 || true
    
    # Set Wine version to Windows 10 for better compatibility
    # wine reg add "HKCU\\Software\\Wine" /v "Version" /t REG_SZ /d "win10" /f >/dev/null 2>&1 || true
    
    # Increase timeout for critical sections (helps with directory.c deadlocks)
    # This is a workaround for the RtlpWaitForCriticalSection timeout issue
    wine reg add "HKCU\\Software\\Wine\\Debug" /v "RelayExclude" /t REG_SZ /d "ntdll.RtlEnterCriticalSection;ntdll.RtlLeaveCriticalSection" /f >/dev/null 2>&1 || true
    
    echo "Registry tweaks applied."
fi

# Ensure /opt/everything is writable before starting Everything
# This is critical for database writes
chmod 755 /opt/everything 2>/dev/null || true
chown $USER_ID:$GROUP_ID /opt/everything 2>/dev/null || true

# Run Everything from data directory
cd /opt/everything
exec env WINEARCH="${WINEARCH}" WINEPREFIX="${WINEPREFIX}" WINE_NO_ASYNC_DIRECTORY=1 wine "$EVERYTHING_PATH" 