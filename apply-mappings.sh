#!/bin/sh
set -e

# This script applies file mappings from mappings.json based on architecture
# Usage: apply-mappings.sh <source_dir> <target_dir> <arch>

SOURCE_DIR="$1"
TARGET_DIR="$2"
ARCH="$3"
MAPPINGS_FILE="${SOURCE_DIR}/mappings.json"

if [ ! -f "$MAPPINGS_FILE" ]; then
    echo "Error: mappings.json not found at $MAPPINGS_FILE"
    exit 1
fi

# Install jq if not available (for JSON parsing)
if ! command -v jq >/dev/null 2>&1; then
    echo "Installing jq for JSON parsing..."
    apt-get update -qq && apt-get install -y -qq jq >/dev/null 2>&1 || {
        echo "Error: jq is required but could not be installed"
        exit 1
    }
fi

# Normalize architecture names
case "$ARCH" in
    amd64|x86_64|x64)
        ARCH_KEY="amd64"
        ;;
    i386|i686|x86)
        ARCH_KEY="i38"
        ;;
    *)
        echo "Warning: Unknown architecture $ARCH, using amd64"
        ARCH_KEY="amd64"
        ;;
esac

echo "Applying mappings for architecture: $ARCH_KEY"

# Create temporary directory for mapped files
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Copy files from "all" section (files that should be copied for all architectures)
echo "Copying common files..."
jq -r '.all | to_entries[] | select(.value == true) | .key' "$MAPPINGS_FILE" | while read -r item; do
    if [ -e "${SOURCE_DIR}/${item}" ]; then
        if [ -d "${SOURCE_DIR}/${item}" ]; then
            echo "  Copying directory: ${item}"
            cp -r "${SOURCE_DIR}/${item}" "${TEMP_DIR}/" 2>/dev/null || true
        else
            echo "  Copying file: ${item}"
            cp "${SOURCE_DIR}/${item}" "${TEMP_DIR}/" 2>/dev/null || true
        fi
    fi
done

# Copy and map files from architecture-specific section
if jq -e ".${ARCH_KEY}" "$MAPPINGS_FILE" >/dev/null 2>&1; then
    echo "Copying architecture-specific files for ${ARCH_KEY}..."
    jq -r ".${ARCH_KEY} | to_entries[] | \"\(.key)|\(.value)\"" "$MAPPINGS_FILE" | while IFS='|' read -r source dest; do
        # Handle array destinations (e.g., ["file1", "file2"])
        if echo "$dest" | grep -q '^\['; then
            # It's an array, extract each destination
            echo "$dest" | jq -r '.[]' | while read -r single_dest; do
                if [ -f "${SOURCE_DIR}/${source}" ]; then
                    echo "  Copying ${source} -> ${single_dest}"
                    mkdir -p "$(dirname "${TEMP_DIR}/${single_dest}")"
                    cp "${SOURCE_DIR}/${source}" "${TEMP_DIR}/${single_dest}" 2>/dev/null || true
                fi
            done
        else
            # Single destination
            if [ -f "${SOURCE_DIR}/${source}" ]; then
                echo "  Copying ${source} -> ${dest}"
                mkdir -p "$(dirname "${TEMP_DIR}/${dest}")"
                cp "${SOURCE_DIR}/${source}" "${TEMP_DIR}/${dest}" 2>/dev/null || true
            fi
        fi
    done
fi

# Set default Everything.exe based on architecture
# For amd64 and i38, prefer everything-1.5.exe, fallback to es.exe
if [ "$ARCH_KEY" = "amd64" ] || [ "$ARCH_KEY" = "i38" ]; then
    if [ -f "${TEMP_DIR}/everything-1.5.exe" ]; then
        cp "${TEMP_DIR}/everything-1.5.exe" "${TEMP_DIR}/Everything.exe" 2>/dev/null || true
    elif [ -f "${TEMP_DIR}/es.exe" ]; then
        cp "${TEMP_DIR}/es.exe" "${TEMP_DIR}/Everything.exe" 2>/dev/null || true
    fi
fi

# Replace source directory with mapped files only
echo "Replacing source directory with mapped files..."
rm -rf "${TARGET_DIR:?}"/*
mv "${TEMP_DIR}"/* "${TARGET_DIR}"/ 2>/dev/null || true

# Set default Everything.exe based on architecture
# For amd64 and i38, prefer everything-1.5.exe, fallback to es.exe
if [ "$ARCH_KEY" = "amd64" ] || [ "$ARCH_KEY" = "i38" ]; then
    if [ -f "${TARGET_DIR}/everything-1.5.exe" ]; then
        cp "${TARGET_DIR}/everything-1.5.exe" "${TARGET_DIR}/Everything.exe" 2>/dev/null || true
    elif [ -f "${TARGET_DIR}/es.exe" ]; then
        cp "${TARGET_DIR}/es.exe" "${TARGET_DIR}/Everything.exe" 2>/dev/null || true
    fi
fi

echo "Mappings applied successfully"
