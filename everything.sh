#!/bin/sh

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

# Create directory structure
mkdir -p /bin /home/everything/.wine

# Create everything user if it doesn't exist (should already exist from Dockerfile, but ensure it)
if ! id -u everything >/dev/null 2>&1; then
    useradd -m -u 99 -g 100 -d /home/everything -s /bin/sh everything || true
fi

# Set up home directory and Wine prefix
export HOME=/home/everything
export WINEPREFIX=/home/everything/.wine

# Adjust ownership of directories
chown -R $USER_ID:$GROUP_ID /home/everything 2>/dev/null || true
chown -R $USER_ID:$GROUP_ID /config 2>/dev/null || true
chown -R $USER_ID:$GROUP_ID /bin 2>/dev/null || true

# Get config path from environment variable (default to /home/everything/everything.ini)
# Support full paths (e.g., /home/everything/everything.ini, /settings/everything.ini) or just filenames (defaults to home dir)
EVERYTHING_CONFIG="${EVERYTHING_CONFIG:-/home/everything/everything.ini}"

# If path is relative (doesn't start with /), assume it's relative to home directory
if [ "${EVERYTHING_CONFIG#/}" = "${EVERYTHING_CONFIG}" ]; then
    EVERYTHING_CONFIG="${HOME}/${EVERYTHING_CONFIG}"
fi

# Ensure parent directory exists
CONFIG_DIR=$(dirname "$EVERYTHING_CONFIG")
mkdir -p "$CONFIG_DIR"
chown -R $USER_ID:$GROUP_ID "$CONFIG_DIR" 2>/dev/null || true

# Ensure config file exists (copy default from image if file doesn't exist - first deployment only)
if [ ! -f "$EVERYTHING_CONFIG" ]; then
    # File doesn't exist, copy default from image
    CONFIG_FILENAME=$(basename "$EVERYTHING_CONFIG")
    if [ -f "/opt/everything-defaults/${CONFIG_FILENAME}" ]; then
        cp "/opt/everything-defaults/${CONFIG_FILENAME}" "$EVERYTHING_CONFIG" 2>/dev/null || true
    elif [ -f "/opt/everything-defaults/everything.ini" ]; then
        # Fallback to default everything.ini if specific config not found
        cp /opt/everything-defaults/everything.ini "$EVERYTHING_CONFIG" 2>/dev/null || true
    elif [ -f "/opt/everything-defaults/Everything.ini" ]; then
        # Fallback to legacy Everything.ini (capital E) if lowercase not found
        cp /opt/everything-defaults/Everything.ini "$EVERYTHING_CONFIG" 2>/dev/null || true
    fi
    chown $USER_ID:$GROUP_ID "$EVERYTHING_CONFIG" 2>/dev/null || true
fi

# Ensure plugins directory exists in /bin (plugins are part of binaries)
mkdir -p /bin/plugins
chown -R $USER_ID:$GROUP_ID /bin/plugins 2>/dev/null || true

# Set up Wine environment
export WINEDEBUG=-fixme-all
export DISPLAY=:0
export WINE_NO_ASYNC_DIRECTORY=1

# Note: WINEARCH is set in the Dockerfile at build time and doesn't need
# to be detected at runtime. The architecture is fixed per container image.
