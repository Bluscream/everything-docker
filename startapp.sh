#!/bin/sh
export HOME=/config
export WINEDEBUG=-fixme-all

# Check if wine is available
if ! command -v wine >/dev/null 2>&1; then
    echo "Error: wine is not installed or not in PATH"
    exit 1
fi

# Configure Wine architecture based on executable
if [ -f "/opt/everything/Everything.exe" ] && file /opt/everything/Everything.exe 2>/dev/null | grep -q "PE32+"; then
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
exec env WINEARCH="${WINEARCH}" wine /opt/everything/Everything.exe 