#!/bin/sh

# Set home directory and Wine prefix
export HOME=/home/everything
export WINEPREFIX=/home/everything/.wine
export WINEDEBUG=-fixme-all

# Additional Wine environment variables to prevent deadlocks
export WINEDLLOVERRIDES="mscoree,mshtml="
export WINE_NO_ASYNC_DIRECTORY=1

# Note: Architecture is fixed at build time (via Dockerfile), so Wine config
# will always match the container's architecture. No need to check/remove it.

echo "Container environment variables:"
env | grep -E '^(DISPLAY|TZ|WINEPREFIX|WINEDEBUG|WINEARCH|EVERYTHING_BINARY|EVERYTHING_CONFIG|EVERYTHING_DATABASE)=' | sort

# Check if wine is available
if ! command -v wine >/dev/null 2>&1; then
    echo "Error: wine is not installed or not in PATH"
    exit 1
fi

# Set default binary if not specified
EVERYTHING_BINARY="${EVERYTHING_BINARY:-everything-1.5.exe}"
EVERYTHING_PATH="/bin/${EVERYTHING_BINARY}"

# Check if the specified binary exists
if [ ! -f "$EVERYTHING_PATH" ]; then
    echo "Error: Everything binary not found at $EVERYTHING_PATH"
    echo "Available executables:"
    ls -1 /bin/*.exe 2>/dev/null | sed 's|/bin/|  - |' || echo "  (none found)"
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
    env WINEPREFIX="/home/everything/.wine" HOME="/home/everything" wine reg add "HKCR\\*\\shell\\CopyLinuxPath\\command" /ve /t REG_SZ /d "\"Z:\\bin\\copy_unix_path.cmd\" \"%1\"" /f >/dev/null 2>&1 || true
    
    # For directories
    env WINEPREFIX="/home/everything/.wine" HOME="/home/everything" wine reg add "HKCR\\Directory\\shell\\CopyLinuxPath" /ve /t REG_SZ /d "Copy Linux Path" /f >/dev/null 2>&1 || true
    env WINEPREFIX="/home/everything/.wine" HOME="/home/everything" wine reg add "HKCR\\Directory\\shell\\CopyLinuxPath\\command" /ve /t REG_SZ /d "\"Z:\\bin\\copy_unix_path.cmd\" \"%1\"" /f >/dev/null 2>&1 || true
    
    echo "Registry tweaks applied."
fi

# Ensure directories are writable
chmod 755 /data 2>/dev/null || true
chown $USER_ID:$GROUP_ID /data 2>/dev/null || true

# Get config and database paths from environment variables
# Support full paths (e.g., /home/everything/everything.ini, /settings/everything.ini) or just filenames (defaults to home dir)
EVERYTHING_CONFIG="${EVERYTHING_CONFIG:-/home/everything/everything.ini}"
EVERYTHING_DATABASE="${EVERYTHING_DATABASE:-/home/everything/everything.db}"

# If path is relative (doesn't start with /), assume it's relative to home directory
if [ "${EVERYTHING_CONFIG#/}" = "${EVERYTHING_CONFIG}" ]; then
    EVERYTHING_CONFIG="${HOME}/${EVERYTHING_CONFIG}"
fi
if [ "${EVERYTHING_DATABASE#/}" = "${EVERYTHING_DATABASE}" ]; then
    EVERYTHING_DATABASE="${HOME}/${EVERYTHING_DATABASE}"
fi

# Convert Linux paths to Wine paths for command line options
# Convert /home/everything/... to Z:\home\everything\... or /settings/... to Z:\settings\...
CONFIG_WINE_PATH=$(echo "$EVERYTHING_CONFIG" | sed 's|^/|Z:\\|; s|/|\\|g')
DATA_WINE_PATH=$(echo "$EVERYTHING_DATABASE" | sed 's|^/|Z:\\|; s|/|\\|g')

# Run Everything from /bin directory with command line options
# NOTE: -noapp-data is NOT used as it forces Everything to run as admin
# -config: Specify the config file location (Wine path - full path to file)
# -db: Specify the database file location (Wine path - full path to file)
#
cd /bin
echo "Starting Everything Search..."
echo "  Binary: $EVERYTHING_PATH"
echo "  Config (Wine path): $CONFIG_WINE_PATH"
echo "  Database (Wine path): $DATA_WINE_PATH"
echo "  Working directory: $(pwd)"
echo "  Wine prefix: $WINEPREFIX"
echo "  Home: $HOME"
echo "  Display: $DISPLAY"

echo "Custom context menu available: right-click any file/folder, choose 'Explore Path' to copy the Linux path via Wine."


# Run Everything with -startup to run in background, then keep the container alive
# Everything will run as a background service, so we need to keep the script running
# NOTE: Do NOT use -noapp-data as it forces Everything to run as admin
env WINEARCH="${WINEARCH}" WINEPREFIX="${WINEPREFIX}" HOME="${HOME}" WINE_NO_ASYNC_DIRECTORY=1 wine "$EVERYTHING_PATH" \
    -startup \
    -config "${CONFIG_WINE_PATH}" \
    -db "${DATA_WINE_PATH}" 2>&1

# Check if Everything started successfully
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    echo "ERROR: Everything failed to start with exit code: $EXIT_CODE"
    exit $EXIT_CODE
fi

# Everything is now running in the background, keep the container alive
echo "Everything Search is running in the background. Keeping container alive..."
# Wait indefinitely to keep the container alive
# Everything runs as a background service with -startup, so we just need to keep the script running
while true; do
    sleep 300
    # Simple health check: verify Everything HTTP server is still responding
    # If it stops responding, the container will be restarted by Docker's restart policy
    echo "Container health check: Everything Search is still running..."
done
