#!/usr/bin/env bash

# Setup local manifests for Exynos 3475 devices.
# This script should be run from the root of your LineageOS source tree.

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Verify we are in the root of the LineageOS source tree
if [ ! -d ".repo" ]; then
    echo "❌ Error: .repo directory not found."
    echo "Please run this script from the root of your LineageOS source tree."
    exit 1
fi

list_devices() {
    local target_version="$1"
    echo "Available devices:"
    local found=0
    for xml in "$SCRIPT_DIR"/*.xml; do
        if [ -f "$xml" ]; then
            basename "$xml" .xml | sed 's/^/  - /'
            found=1
        fi
    done
    if [ $found -eq 0 ]; then
        if [ -n "$target_version" ]; then
            local remote_devices
            remote_devices=$(curl -s "${API_URL}${target_version}?recursive=1" | grep '"path":' | cut -d '"' -f 4 | grep '\.xml$' | grep -v '/')
            if [ -n "$remote_devices" ]; then
                for file in $remote_devices; do
                    basename "$file" .xml | sed 's/^/  - /'
                done
                return
            fi
        fi
        echo "  (No local devices found. Specify a valid version to fetch from remote.)"
    fi
}

VERSION="$1"
DEVICE="$2"
REPO="samsungexynos3475/local_manifests"
REPO_URL="https://raw.githubusercontent.com/$REPO/lineage-"
API_URL="https://api.github.com/repos/$REPO/git/trees/lineage-"

if [ -z "$VERSION" ] || [ -z "$DEVICE" ]; then
    echo "❌ Error: Version or Device name not specified."
    echo "Usage: $0 <version> <device_name> (e.g., $0 17.1 j2lte)"
    echo ""
    list_devices "$VERSION"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/$DEVICE.xml" ]; then
    # Validate against remote devices if local files are missing
    remote_devices=$(curl -s "${API_URL}${VERSION}?recursive=1" | grep '"path":' | cut -d '"' -f 4 | grep '\.xml$' | grep -v '/')
    if ! echo "$remote_devices" | grep -q "^$DEVICE\.xml$"; then
        echo "❌ Error: Device '$DEVICE' is not supported."
        echo ""
        list_devices "$VERSION"
        exit 1
    fi
fi

echo "⚙️ Setting up local manifest for '$DEVICE' (LineageOS $VERSION)..."

# Ensure target directory exists
mkdir -p .repo/local_manifests

# Copy or download common configuration
if [ -d "$SCRIPT_DIR/default" ] || [ -f "$SCRIPT_DIR/$DEVICE.xml" ]; then
    echo "📂 Copying local XML files for '$DEVICE' to .repo/local_manifests/..."
    find "$SCRIPT_DIR" -name "*.xml" -type f | while read -r xml_file; do
        rel_path="${xml_file#$SCRIPT_DIR/}"
        if [[ "$rel_path" == */* ]] || [[ "$rel_path" == "$DEVICE.xml" ]]; then
            mkdir -p ".repo/local_manifests/$(dirname "$rel_path")"
            cp "$xml_file" ".repo/local_manifests/$rel_path"
        fi
    done
    echo "✅ Copied local configuration files"
else
    echo "🌐 Local files not found. Fetching all XML configurations from remote..."
    FILES=$(curl -s "${API_URL}${VERSION}?recursive=1" | grep '"path":' | cut -d '"' -f 4 | grep '\.xml$')
    
    if [ -z "$FILES" ]; then
        echo "❌ Error: Could not fetch file list from remote for lineage-$VERSION, or no XML files found."
        exit 1
    fi
    
    for file in $FILES; do
        if [[ "$file" == */* ]] || [[ "$file" == "$DEVICE.xml" ]]; then
            echo "⬇️ Downloading $file..."
            mkdir -p ".repo/local_manifests/$(dirname "$file")"
            curl -sf "${REPO_URL}${VERSION}/$file" -o ".repo/local_manifests/$file"
            if [ $? -ne 0 ]; then
                echo "❌ Error: Failed to download $file"
                exit 1
            fi
        fi
    done
    echo "✅ Downloaded manifest files for '$DEVICE' successfully."
fi

echo "🎉 Setup complete! You can now run: repo sync"
