#!/bin/sh

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

# Create directory structure
mkdir -p /home/everything/plugins /home/everything/html /home/everything/cfg /home/everything/data /home/everything/.wine /home/everything/.config

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

# Get config path from environment variable (default to cfg/everything.ini relative to home)
# Support full paths or relative paths (relative to home directory)
EVERYTHING_CFG="${EVERYTHING_CFG:-cfg/everything.ini}"

# If path is relative (doesn't start with /), assume it's relative to home directory
if [ "${EVERYTHING_CFG#/}" = "${EVERYTHING_CFG}" ]; then
    EVERYTHING_CFG="${HOME}/${EVERYTHING_CFG}"
fi

# Ensure parent directory exists
CONFIG_DIR=$(dirname "$EVERYTHING_CFG")
mkdir -p "$CONFIG_DIR"
chown -R $USER_ID:$GROUP_ID "$CONFIG_DIR" 2>/dev/null || true

# Ensure config file exists (copy default from image if file doesn't exist - first deployment only)
if [ ! -f "$EVERYTHING_CFG" ]; then
    # File doesn't exist, copy default from image
    cp /opt/everything-defaults/everything.ini "$EVERYTHING_CFG" 2>/dev/null || true
    chown $USER_ID:$GROUP_ID "$EVERYTHING_CFG" 2>/dev/null || true
fi

# Ensure plugins config file exists
PLUGINS_CFG="${HOME}/cfg/Plugins-1.5a.ini"
if [ ! -f "$PLUGINS_CFG" ]; then
    cp /opt/everything-defaults/Plugins-1.5a.ini "$PLUGINS_CFG" 2>/dev/null || true
    chown $USER_ID:$GROUP_ID "$PLUGINS_CFG" 2>/dev/null || true
fi

# Ensure plugins directory exists
mkdir -p /home/everything/plugins
chown -R $USER_ID:$GROUP_ID /home/everything/plugins 2>/dev/null || true

# Set up Wine environment
export WINEDEBUG=-fixme-all
export DISPLAY=:0
export WINE_NO_ASYNC_DIRECTORY=1

# Note: WINEARCH is set in the Dockerfile at build time and doesn't need
# to be detected at runtime. The architecture is fixed per container image.
