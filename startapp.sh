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
# If we need win64 but prefix is 32-bit, remove it
if [ -d "/home/everything/.wine" ] && [ -f "/home/everything/.wine/system.reg" ]; then
    if [ "$WINEARCH" = "win64" ]; then
        # Check if prefix is 32-bit by trying to run wine64 with a test
        # The error message will contain "32-bit installation" if prefix is wrong
        if command -v wine64 >/dev/null 2>&1; then
            WINE_TEST_OUTPUT=$(env WINEARCH=win64 WINEPREFIX="/home/everything/.wine" HOME="/home/everything" wine64 cmd /c exit 2>&1)
            if echo "$WINE_TEST_OUTPUT" | grep -qi "32-bit installation\|cannot support 64-bit"; then
                echo "WARNING: Wine prefix is 32-bit but we need 64-bit. Removing old prefix..."
                rm -rf "/home/everything/.wine"
            fi
        fi
    fi
fi

# Initialize Wine prefix if it doesn't exist
if [ ! -d "/home/everything/.wine" ] || [ ! -f "/home/everything/.wine/system.reg" ]; then
    echo "Initializing Wine prefix at /home/everything/.wine with architecture $WINEARCH..."
    env WINEARCH="$WINEARCH" WINEPREFIX="/home/everything/.wine" HOME="/home/everything" wineboot --init 2>&1 || {
        echo "ERROR: Failed to initialize Wine prefix. This may indicate a missing Wine installation."
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
    
    echo "Registry tweaks applied."
fi

# Ensure directories are writable
chmod 755 /data 2>/dev/null || true
chown $USER_ID:$GROUP_ID /data 2>/dev/null || true

# Get config and database paths from environment variables
# Support full paths (e.g., ~/everything.ini, /settings/everything.ini) or just filenames (defaults to home dir)
EVERYTHING_CONFIG="${EVERYTHING_CONFIG:-~/everything.ini}"
EVERYTHING_DATABASE="${EVERYTHING_DATABASE:-~/everything.db}"

# Expand ~ to home directory if present (portable method for /bin/sh)
case "$EVERYTHING_CONFIG" in
    ~/*) EVERYTHING_CONFIG="${HOME}${EVERYTHING_CONFIG#~}" ;;
    ~) EVERYTHING_CONFIG="$HOME" ;;
esac
case "$EVERYTHING_DATABASE" in
    ~/*) EVERYTHING_DATABASE="${HOME}${EVERYTHING_DATABASE#~}" ;;
    ~) EVERYTHING_DATABASE="$HOME" ;;
esac

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
# -noapp-data: Store settings and data in the same location as the executable (not in %APPDATA%)
# -config: Specify the config file location (Wine path - full path to file)
# -db: Specify the database file location (Wine path - full path to file)
cd /bin
exec env WINEARCH="${WINEARCH}" WINEPREFIX="${WINEPREFIX}" HOME="${HOME}" WINE_NO_ASYNC_DIRECTORY=1 wine "$EVERYTHING_PATH" \
    -noapp-data \
    -config "${CONFIG_WINE_PATH}" \
    -db "${DATA_WINE_PATH}"
