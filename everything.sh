#!/bin/sh

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

# Make sure required directories exist.
mkdir -p "$XDG_CONFIG_HOME/Everything"
mkdir -p "$XDG_DATA_HOME"

# Adjust ownership of /config.
chown -R $USER_ID:$GROUP_ID /config
# Adjust ownership of /cache
chown -R $USER_ID:$GROUP_ID /cache

# Set up Wine environment
export WINEDEBUG=-fixme-all
export DISPLAY=:0

# Function to remove existing Wine configuration if present
remove_wine_config() {
    if [ -d "/config/.wine" ]; then
        echo "Detected existing Wine configuration, removing for architecture switch..."
        rm -rf /config/.wine
    fi
}

# Configure Wine architecture and clear existing config if needed
if [ "${EVERYTHING_ARCH}" = "x64" ]; then
    export WINEARCH=win64
    remove_wine_config
else
    export WINEARCH=win32
    remove_wine_config
fi 