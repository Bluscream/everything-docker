#!/bin/sh

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

# Make sure required directories exist
mkdir -p "$XDG_CONFIG_HOME/Everything"
mkdir -p "$XDG_DATA_HOME"

# Adjust ownership of /config
chown -R $USER_ID:$GROUP_ID /config

# Files that should be preserved (config/data) - not overwritten on updates
PRESERVE_FILES="Everything.ini Everything-1.5a.ini plugins.ini plugins-1.5a.ini Everything.db Everything-1.5a.db"

# Initialize Everything data directory if volume is empty (first deployment)
if [ -z "$(ls -A /opt/everything 2>/dev/null)" ]; then
    echo "Initializing Everything data directory from image (first deployment)..."
    cp -r /opt/everything-image/* /opt/everything/ 2>/dev/null || true
else
    # Update binaries and static content, but preserve config/data files
    echo "Updating binaries and static content from image..."
    
    # Create temporary directory for preserved files
    mkdir -p /tmp/everything-preserve
    
    # Backup config/data files
    for file in $PRESERVE_FILES; do
        if [ -f "/opt/everything/$file" ]; then
            cp "/opt/everything/$file" "/tmp/everything-preserve/$file" 2>/dev/null || true
        fi
    done
    
    # Copy all files from image (overwrites binaries/static content)
    cp -r /opt/everything-image/* /opt/everything/ 2>/dev/null || true
    
    # Restore preserved config/data files
    for file in $PRESERVE_FILES; do
        if [ -f "/tmp/everything-preserve/$file" ]; then
            cp "/tmp/everything-preserve/$file" "/opt/everything/$file" 2>/dev/null || true
        fi
    done
    
    # Cleanup
    rm -rf /tmp/everything-preserve
fi

# Ensure config files exist (copy defaults if missing - first deployment only)
[ ! -f "/opt/everything/Everything.ini" ] && [ -f "/opt/everything-defaults/Everything.ini" ] && \
    cp /opt/everything-defaults/Everything.ini /opt/everything/Everything.ini
[ ! -f "/opt/everything/Everything-1.5a.ini" ] && [ -f "/opt/everything-defaults/Everything.ini" ] && \
    cp /opt/everything-defaults/Everything.ini /opt/everything/Everything-1.5a.ini
[ ! -f "/opt/everything/plugins.ini" ] && [ -f "/opt/everything-defaults/plugins.ini" ] && \
    cp /opt/everything-defaults/plugins.ini /opt/everything/plugins.ini
[ ! -f "/opt/everything/plugins-1.5a.ini" ] && [ -f "/opt/everything-defaults/plugins.ini" ] && \
    cp /opt/everything-defaults/plugins.ini /opt/everything/plugins-1.5a.ini

# Ensure plugins directory exists and is writable
mkdir -p /opt/everything/plugins
chown -R $USER_ID:$GROUP_ID /opt/everything/plugins

# Adjust ownership of Everything directory
chown -R $USER_ID:$GROUP_ID /opt/everything 2>/dev/null || true

# Set up Wine environment
export WINEDEBUG=-fixme-all
export DISPLAY=:0

# Configure Wine architecture based on executable
if [ -f "/opt/everything/Everything.exe" ] && file /opt/everything/Everything.exe 2>/dev/null | grep -q "PE32+"; then
    export WINEARCH=win64
else
    export WINEARCH=win32
fi
