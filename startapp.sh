#!/bin/sh
export HOME=/config
export WINEDEBUG=-fixme-all

# Check if wine is available
if ! command -v wine >/dev/null 2>&1; then
    echo "Error: wine is not installed or not in PATH"
    exit 1
fi

# Configure Wine based on architecture
if [ "${EVERYTHING_ARCH}" = "x64" ]; then
    # For 64-bit, use wine with win64 architecture
    export WINEARCH=win64
    exec env wine /opt/everything/Everything.exe
else
    # For 32-bit, use wine with win32 architecture
    export WINEARCH=win32
    exec env wine /opt/everything/Everything.exe
fi 