#!/bin/sh

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

# Create directory structure
mkdir -p /home/everything/plugins /home/everything/html /home/everything/cfg /home/everything/.wine /home/everything/.config

# Create everything user if it doesn't exist (should already exist from Dockerfile, but ensure it)
if ! id -u everything >/dev/null 2>&1; then
    useradd -m -u 99 -g 100 -d /home/everything -s /bin/sh everything || true
fi

# Set up home directory and Wine prefix
export HOME=/home/everything
export WINEPREFIX=/home/everything/.wine

# Create symlink from /config to /home/everything/.config for base image compatibility
# The base image (jlesage/baseimage-gui) expects /config for VNC passwords, certificates, etc.
# We store it in /home/everything/.config/ and symlink it
if [ ! -L /config ] && [ ! -d /config ]; then
    # Remove /config if it exists as a directory (from image build)
    rm -rf /config 2>/dev/null || true
    # Create symlink
    ln -s /home/everything/.config /config
fi

# Copy files from image to volume on first run (if volume is empty)
# The volume mount overwrites /home/everything, so we need to copy files from /opt/everything-files
# Check if executables exist - if not, this is first run and we need to copy from image
if [ ! -f "/home/everything/everything-1.5.exe" ]; then
    echo "First run detected - copying files from image to volume..."
    
    # Copy all files from /opt/everything-files to /home/everything
    if [ -d "/opt/everything-files" ]; then
        cp -r /opt/everything-files/* /home/everything/ 2>/dev/null || true
        echo "Files copied from image to volume"
    else
        echo "Warning: /opt/everything-files not found - files may not be available"
    fi
fi

# Adjust ownership of directories
chown -R $USER_ID:$GROUP_ID /home/everything 2>/dev/null || true

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

# Ensure plugins config file exists (must be next to everything.exe, not in cfg/)
PLUGINS_CFG="${HOME}/Plugins-1.5a.ini"
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
# WINE_NO_ASYNC_DIRECTORY is configurable via environment variable (defaults to 1 if not set)
export WINE_NO_ASYNC_DIRECTORY="${WINE_NO_ASYNC_DIRECTORY:-1}"

# Print all environment variables
echo "Container initialization environment variables:"
env | sort

# Note: WINEARCH is set in the Dockerfile at build time and doesn't need
# to be detected at runtime. The architecture is fixed per container image.
