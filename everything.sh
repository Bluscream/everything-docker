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
    echo "Copying files from image (this may take a moment)..."
    # Copy all files including all architecture variants
    # Use rsync if available for better progress, otherwise use cp
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --info=progress2 /opt/everything-image/ /opt/everything/ 2>&1 | head -1 || \
        cp -r /opt/everything-image/* /opt/everything/ 2>/dev/null || true
    else
        cp -r /opt/everything-image/* /opt/everything/ 2>/dev/null || true
    fi
    echo "Files copied successfully."
else
    # Update binaries and static content, but preserve config/data files
    echo "Updating binaries and static content from image..."
    
    # Create temporary directory for preserved files
    mkdir -p /tmp/everything-preserve
    
    # Backup config/data files
    echo "Backing up configuration files..."
    for file in $PRESERVE_FILES; do
        if [ -f "/opt/everything/$file" ]; then
            cp "/opt/everything/$file" "/tmp/everything-preserve/$file" 2>/dev/null || true
        fi
    done
    
    # Copy all files from image (overwrites binaries/static content, keeps all arch variants)
    echo "Copying files from image (this may take a moment)..."
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --info=progress2 /opt/everything-image/ /opt/everything/ 2>&1 | head -1 || \
        cp -r /opt/everything-image/* /opt/everything/ 2>/dev/null || true
    else
        cp -r /opt/everything-image/* /opt/everything/ 2>/dev/null || true
    fi
    
    # Restore preserved config/data files
    echo "Restoring configuration files..."
    for file in $PRESERVE_FILES; do
        if [ -f "/tmp/everything-preserve/$file" ]; then
            cp "/tmp/everything-preserve/$file" "/opt/everything/$file" 2>/dev/null || true
        fi
    done
    
    # Cleanup
    rm -rf /tmp/everything-preserve
    echo "Update completed."
fi

# Ensure config files exist (copy defaults if missing - first deployment only)
# Use files from image if available, otherwise use defaults
[ ! -f "/opt/everything/Everything.ini" ] && \
    { [ -f "/opt/everything-image/Everything-1.5a.ini" ] && cp /opt/everything-image/Everything-1.5a.ini /opt/everything/Everything.ini || \
      [ -f "/opt/everything-defaults/Everything.ini" ] && cp /opt/everything-defaults/Everything.ini /opt/everything/Everything.ini || true; }
[ ! -f "/opt/everything/Everything-1.5a.ini" ] && \
    { [ -f "/opt/everything-image/Everything-1.5a.ini" ] && cp /opt/everything-image/Everything-1.5a.ini /opt/everything/Everything-1.5a.ini || \
      [ -f "/opt/everything-defaults/Everything.ini" ] && cp /opt/everything-defaults/Everything.ini /opt/everything/Everything-1.5a.ini || true; }
[ ! -f "/opt/everything/plugins.ini" ] && \
    { [ -f "/opt/everything-image/Plugins-1.5a.ini" ] && cp /opt/everything-image/Plugins-1.5a.ini /opt/everything/plugins.ini || \
      [ -f "/opt/everything-defaults/plugins.ini" ] && cp /opt/everything-defaults/plugins.ini /opt/everything/plugins.ini || true; }
[ ! -f "/opt/everything/plugins-1.5a.ini" ] && \
    { [ -f "/opt/everything-image/Plugins-1.5a.ini" ] && cp /opt/everything-image/Plugins-1.5a.ini /opt/everything/plugins-1.5a.ini || \
      [ -f "/opt/everything-defaults/plugins.ini" ] && cp /opt/everything-defaults/plugins.ini /opt/everything/plugins-1.5a.ini || true; }

# Ensure plugins directory exists and is writable
echo "Setting up plugins directory..."
mkdir -p /opt/everything/plugins
chown -R $USER_ID:$GROUP_ID /opt/everything/plugins 2>/dev/null || true

# Adjust ownership of Everything directory (skip if on slow network mount)
echo "Setting file permissions..."
# Only chown specific directories/files to avoid hanging on large network mounts
chown -R $USER_ID:$GROUP_ID /opt/everything/*.exe 2>/dev/null || true
chown -R $USER_ID:$GROUP_ID /opt/everything/*.dll 2>/dev/null || true
chown -R $USER_ID:$GROUP_ID /opt/everything/*.ini 2>/dev/null || true
chown -R $USER_ID:$GROUP_ID /opt/everything/*.db 2>/dev/null || true
chown -R $USER_ID:$GROUP_ID /opt/everything/*.lng 2>/dev/null || true
chown -R $USER_ID:$GROUP_ID /opt/everything/*.chm 2>/dev/null || true
chown -R $USER_ID:$GROUP_ID /opt/everything/plugins 2>/dev/null || true
# Try to chown html directory but don't fail if it's slow
timeout 10 chown -R $USER_ID:$GROUP_ID /opt/everything/html 2>/dev/null || true

# Set up Wine environment
export WINEDEBUG=-fixme-all
export DISPLAY=:0

# Remove Wine config early to prevent architecture conflicts
# This must happen before any Wine command is executed
if [ -d "/config/.wine" ]; then
    rm -rf /config/.wine
fi

# Configure Wine architecture based on executable (if EVERYTHING_BINARY is set)
# This is informational only - actual WINEARCH will be set in startapp.sh
if [ -n "${EVERYTHING_BINARY:-}" ] && [ -f "/opt/everything/${EVERYTHING_BINARY}" ]; then
    if command -v file >/dev/null 2>&1 && file "/opt/everything/${EVERYTHING_BINARY}" 2>/dev/null | grep -q "PE32+"; then
        export WINEARCH=win64
    else
        export WINEARCH=win32
    fi
fi
