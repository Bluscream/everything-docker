#!/bin/sh
export HOME=/config
export WINEDEBUG=-fixme-all

# Check if wine is available
if ! command -v wine >/dev/null 2>&1; then
    echo "Error: wine is not installed or not in PATH"
    exit 1
fi

# Set default binary if not specified
EVERYTHING_BINARY="${EVERYTHING_BINARY:-everything-1.5_x64.exe}"
EVERYTHING_PATH="/opt/everything/${EVERYTHING_BINARY}"

# Check if the specified binary exists
if [ ! -f "$EVERYTHING_PATH" ]; then
    echo "Error: Everything binary not found at $EVERYTHING_PATH"
    echo "Available executables:"
    ls -1 /opt/everything/*.exe 2>/dev/null | sed 's|/opt/everything/|  - |' || echo "  (none found)"
    exit 1
fi

# Configure Wine architecture based on executable
if file "$EVERYTHING_PATH" 2>/dev/null | grep -q "PE32+"; then
    export WINEARCH=win64
else
    export WINEARCH=win32
fi

# Remove existing Wine configuration to avoid architecture conflicts
if [ -d "/config/.wine" ]; then
    rm -rf /config/.wine
fi

# Run Everything from data directory
cd /opt/everything
exec env WINEARCH="${WINEARCH}" wine "$EVERYTHING_PATH" 