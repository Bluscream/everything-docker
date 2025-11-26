#!/bin/sh

# Set home directory and Wine prefix
export HOME=/home/everything
export WINEPREFIX=/home/everything/.wine
export WINEDEBUG=-fixme-all

# Additional Wine environment variables to prevent deadlocks
export WINEDLLOVERRIDES="mscoree,mshtml="
# WINE_NO_ASYNC_DIRECTORY is now configurable via environment variable (defaults to 1 if not set)
export WINE_NO_ASYNC_DIRECTORY="${WINE_NO_ASYNC_DIRECTORY:-1}"

# Note: Architecture is fixed at build time (via Dockerfile), so Wine config
# will always match the container's architecture. No need to check/remove it.

echo "Container environment variables:"
env | sort

# Check if wine is available
if ! command -v wine >/dev/null 2>&1; then
    echo "Error: wine is not installed or not in PATH"
    exit 1
fi

# Set default binary if not specified
EVERYTHING_BIN="${EVERYTHING_BIN:-everything-1.5.exe}"
EVERYTHING_PATH="${HOME}/${EVERYTHING_BIN}"

# Check if the specified binary exists
if [ ! -f "$EVERYTHING_PATH" ]; then
    echo "Error: Everything binary not found at $EVERYTHING_PATH"
    echo "Available executables:"
    ls -1 ${HOME}/*.exe 2>/dev/null | sed "s|${HOME}/|  - |" || echo "  (none found)"
    exit 1
fi

# WINEARCH is already set in the Dockerfile (win64 for amd64, win32 for i386)
# No need to detect architecture at runtime - trust the build-time setting
# Ensure WINEARCH is set (fallback for safety, though it should always be set)
export WINEARCH="${WINEARCH:-win64}"

# Check if Wine prefix exists and has the correct architecture
# If we need win64 but prefix is 32-bit, we need to remove it (but it might be a mounted volume)
if [ -d "/home/everything/.wine" ] && [ -f "/home/everything/.wine/system.reg" ]; then
    if [ "$WINEARCH" = "win64" ]; then
        # Check if prefix is 32-bit by examining the registry or trying wine64
        ARCH_MISMATCH=false
        
        # Method 1: Check registry for wine vs wine64 references
        if grep -q '"wine"' "/home/everything/.wine/system.reg" 2>/dev/null && ! grep -q '"wine64"' "/home/everything/.wine/system.reg" 2>/dev/null; then
            # Registry mentions wine but not wine64 - likely 32-bit
            ARCH_MISMATCH=true
        fi
        
        # Method 2: Try to run wine64 - if it fails with architecture error, prefix is wrong
        if [ "$ARCH_MISMATCH" = "false" ] && command -v wine64 >/dev/null 2>&1; then
            WINE_TEST=$(env WINEARCH=win64 WINEPREFIX="/home/everything/.wine" HOME="/home/everything" wine64 --version 2>&1)
            if echo "$WINE_TEST" | grep -qi "32-bit installation\|cannot support 64-bit"; then
                ARCH_MISMATCH=true
            fi
        fi
        
        if [ "$ARCH_MISMATCH" = "true" ]; then
            echo "ERROR: Wine prefix at /home/everything/.wine is 32-bit but we need 64-bit."
            echo "Please remove the .wine directory from the host and restart the container."
            echo "On the host, run: rm -rf ./.wine (or the equivalent path in your docker-compose.yml)"
            exit 1
        fi
    fi
fi

# Initialize Wine prefix if it doesn't exist
if [ ! -d "/home/everything/.wine" ] || [ ! -f "/home/everything/.wine/system.reg" ]; then
    echo "Initializing Wine prefix at /home/everything/.wine with architecture $WINEARCH..."
    env WINEARCH="$WINEARCH" WINEPREFIX="/home/everything/.wine" HOME="/home/everything" wineboot --init 2>&1 || {
        echo "ERROR: Failed to initialize Wine prefix. This may indicate:"
        echo "  1. Missing Wine installation (wine32 required for win64)"
        echo "  2. Existing 32-bit prefix that needs to be removed"
        echo "  3. Permission issues with /home/everything/.wine"
        exit 1
    }
    
    # Wait a moment for Wine to fully initialize
    sleep 2
fi

# Apply registry tweaks to prevent deadlocks and COM marshalling issues
# Apply these on every startup to ensure they're always set
# Only apply if Wine prefix exists and is accessible
if [ -d "/home/everything/.wine" ] && [ -f "/home/everything/.wine/system.reg" ]; then
    echo "Applying Wine registry tweaks to prevent deadlocks..."
    
    # Ensure registry keys exist
    env WINEPREFIX="/home/everything/.wine" HOME="/home/everything" wine reg add "HKCU\\Software\\Wine" /f >/dev/null 2>&1 || true
    env WINEPREFIX="/home/everything/.wine" HOME="/home/everything" wine reg add "HKCU\\Software\\Wine\\DllOverrides" /f >/dev/null 2>&1 || true
    env WINEPREFIX="/home/everything/.wine" HOME="/home/everything" wine reg add "HKCU\\Software\\Wine\\Debug" /f >/dev/null 2>&1 || true
    env WINEPREFIX="/home/everything/.wine" HOME="/home/everything" wine reg add "HKCU\\Software\\Wine\\FileSystem" /f >/dev/null 2>&1 || true
    
    # Increase timeout for critical sections (helps with directory.c deadlocks)
    # This is a workaround for the RtlpWaitForCriticalSection timeout issue
    env WINEPREFIX="/home/everything/.wine" HOME="/home/everything" wine reg add "HKCU\\Software\\Wine\\Debug" /v "RelayExclude" /t REG_SZ /d "ntdll.RtlEnterCriticalSection;ntdll.RtlLeaveCriticalSection" /f >/dev/null 2>&1 || true
    
    # Register custom verb "Copy Linux Path" in Windows context menu
    # This makes the custom verb available system-wide in Wine, not just in Everything
    # For all file types (*)
    env WINEPREFIX="/home/everything/.wine" HOME="/home/everything" wine reg add "HKCR\\*\\shell\\CopyLinuxPath" /ve /t REG_SZ /d "Copy Linux Path" /f >/dev/null 2>&1 || true
    env WINEPREFIX="/home/everything/.wine" HOME="/home/everything" wine reg add "HKCR\\*\\shell\\CopyLinuxPath\\command" /ve /t REG_SZ /d "\"Z:\\home\\everything\\copy_unix_path.cmd\" \"%1\"" /f >/dev/null 2>&1 || true
    
    # For directories
    env WINEPREFIX="/home/everything/.wine" HOME="/home/everything" wine reg add "HKCR\\Directory\\shell\\CopyLinuxPath" /ve /t REG_SZ /d "Copy Linux Path" /f >/dev/null 2>&1 || true
    env WINEPREFIX="/home/everything/.wine" HOME="/home/everything" wine reg add "HKCR\\Directory\\shell\\CopyLinuxPath\\command" /ve /t REG_SZ /d "\"Z:\\home\\everything\\copy_unix_path.cmd\" \"%1\"" /f >/dev/null 2>&1 || true
    
    echo "Registry tweaks applied."
fi

# Get config and database paths from environment variables
# Support relative paths (defaults to cfg/everything.ini and db/everything.db relative to home)
# or full paths (e.g., /home/everything/cfg/everything.ini)
EVERYTHING_CFG="${EVERYTHING_CFG:-cfg/everything.ini}"
EVERYTHING_DB="${EVERYTHING_DB:-db/everything.db}"

# Store original values for display
EVERYTHING_CFG_ORIG="$EVERYTHING_CFG"
EVERYTHING_DB_ORIG="$EVERYTHING_DB"

# If path is absolute, convert to relative path from HOME for Wine
# If path is relative, use it as-is
if [ "${EVERYTHING_CFG#/}" != "${EVERYTHING_CFG}" ]; then
    # Absolute path - convert to relative from HOME
    EVERYTHING_CFG="${EVERYTHING_CFG#${HOME}/}"
fi
if [ "${EVERYTHING_DB#/}" != "${EVERYTHING_DB}" ]; then
    # Absolute path - convert to relative from HOME
    EVERYTHING_DB="${EVERYTHING_DB#${HOME}/}"
fi

# Convert forward slashes to backslashes for Wine (Windows paths)
EVERYTHING_CFG_WINE=$(echo "$EVERYTHING_CFG" | sed 's/\//\\/g')
EVERYTHING_DB_WINE=$(echo "$EVERYTHING_DB" | sed 's/\//\\/g')

# Run Everything from home directory with paths from environment variables
# NOTE: -noapp-data is NOT used as it forces Everything to run as admin
# -config: Specify the config file location (relative path from home directory)
# -db: Specify the database file location (relative path from home directory)
cd "${HOME}"
echo "Starting Everything Search..."
echo "  Binary: $EVERYTHING_PATH"
echo "  Config: $EVERYTHING_CFG_ORIG (from EVERYTHING_CFG)"
echo "  Database: $EVERYTHING_DB_ORIG (from EVERYTHING_DB)"
echo "  Working directory: $(pwd)"
echo "  Wine prefix: $WINEPREFIX"
echo "  Home: $HOME"
echo "  Display: $DISPLAY"

echo "Custom context menu available: right-click any file/folder, choose 'Explore Path' to copy the Linux path via Wine."

# Run Everything in foreground (without -startup flag)
# Everything will run in the foreground and keep the container alive
# NOTE: Do NOT use -noapp-data as it forces Everything to run as admin
# Use paths from environment variables (converted to Windows format for Wine)
echo "Everything Search is running in the foreground. Container will stay alive while Everything is running."
env WINEARCH="${WINEARCH}" WINEPREFIX="${WINEPREFIX}" HOME="${HOME}" WINE_NO_ASYNC_DIRECTORY="${WINE_NO_ASYNC_DIRECTORY:-1}" wine "$EVERYTHING_PATH" \
    -config "$EVERYTHING_CFG_WINE" \
    -db "$EVERYTHING_DB_WINE" 2>&1

# If Everything exits, the container will exit (Docker restart policy will handle restarts)
EXIT_CODE=$?
echo "Everything Search exited with code: $EXIT_CODE"
exit $EXIT_CODE
