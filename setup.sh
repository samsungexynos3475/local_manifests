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
shift
DEVICES=("$@")
REPO="samsungexynos3475/local_manifests"
REPO_URL="https://raw.githubusercontent.com/$REPO/lineage-"
API_URL="https://api.github.com/repos/$REPO/git/trees/lineage-"

if [ -z "$VERSION" ] || [ ${#DEVICES[@]} -eq 0 ]; then
    echo "❌ Error: Version or Device name(s) not specified."
    echo "Usage: $0 <version> <device_1> [device_2] ... (e.g., $0 17.1 j2lte j1xlte)"
    echo ""
    list_devices "$VERSION"
    exit 1
fi

# Fetch remote list once if any device is not local
remote_devices=""
for DEV in "${DEVICES[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$DEV.xml" ]; then
        if [ -z "$remote_devices" ]; then
            remote_devices=$(curl -s "${API_URL}${VERSION}?recursive=1" | grep '"path":' | cut -d '"' -f 4 | grep '\.xml$' | grep -v '/')
        fi
        if ! echo "$remote_devices" | grep -q "^$DEV\.xml$"; then
            echo "❌ Error: Device '$DEV' is not supported."
            echo ""
            list_devices "$VERSION"
            exit 1
        fi
    fi
done

echo "⚙️ Setting up local manifest for devices: ${DEVICES[*]} (LineageOS $VERSION)..."

# Ensure target directory exists
mkdir -p .repo/local_manifests
ROOMSERVICE=".repo/local_manifests/roomservices.xml"

# 1. Copy or download the base device manifest (First device)
FIRST_DEVICE="${DEVICES[0]}"
if [ -f "$SCRIPT_DIR/$FIRST_DEVICE.xml" ]; then
    echo "📂 Using local $FIRST_DEVICE.xml as base for roomservices.xml..."
    cat "$SCRIPT_DIR/$FIRST_DEVICE.xml" > "$ROOMSERVICE"
else
    echo "🌐 Fetching $FIRST_DEVICE.xml from remote as base for roomservices.xml..."
    curl -sf "${REPO_URL}${VERSION}/$FIRST_DEVICE.xml" -o "$ROOMSERVICE"
    if [ $? -ne 0 ]; then
        echo "❌ Error: Failed to download $FIRST_DEVICE.xml"
        exit 1
    fi
fi

# 2. Extract contents of any additional devices
EXTRA_DEVICES_CONTENT=""
for (( i=1; i<${#DEVICES[@]}; i++ )); do
    DEV="${DEVICES[$i]}"
    if [ -f "$SCRIPT_DIR/$DEV.xml" ]; then
        echo "📂 Reading local $DEV.xml to merge..."
        raw_content=$(cat "$SCRIPT_DIR/$DEV.xml")
    else
        echo "🌐 Fetching remote $DEV.xml to merge..."
        raw_content=$(curl -sf "${REPO_URL}${VERSION}/$DEV.xml")
        if [ $? -ne 0 ]; then
            echo "❌ Error: Failed to download $DEV.xml"
            exit 1
        fi
    fi
    # Strip xml tags, manifest tags, and the Exynos include block
    cleaned_content=$(echo "$raw_content" | grep -v '<?xml' | grep -v '<manifest>' | grep -v '</manifest>' | awk '
        /<!-- Exynos 3475 -->/ {
            getline
            next
        }
        { print }
    ')
    # Add proper spacing when merging multiple devices
    if [ -z "$EXTRA_DEVICES_CONTENT" ]; then
        EXTRA_DEVICES_CONTENT="$cleaned_content"
    else
        EXTRA_DEVICES_CONTENT="$EXTRA_DEVICES_CONTENT

$cleaned_content"
    fi
done

# 3. Get the inner content of exynos3475.xml (stripping xml and manifest tags)
if [ -f "$SCRIPT_DIR/default/exynos3475.xml" ]; then
    echo "📂 Reading local default/exynos3475.xml to merge..."
    EXYNOS_CONTENT=$(grep -v '<?xml' "$SCRIPT_DIR/default/exynos3475.xml" | grep -v '<manifest>' | grep -v '</manifest>')
else
    echo "🌐 Fetching remote default/exynos3475.xml to merge..."
    EXYNOS_CONTENT=$(curl -sf "${REPO_URL}${VERSION}/default/exynos3475.xml" | grep -v '<?xml' | grep -v '<manifest>' | grep -v '</manifest>')
    if [ $? -ne 0 ]; then
        echo "❌ Error: Failed to download default/exynos3475.xml"
        exit 1
    fi
fi

# Combine the extra devices with the exynos common content
if [ -n "$EXTRA_DEVICES_CONTENT" ]; then
    FULL_REPLACEMENT="$EXTRA_DEVICES_CONTENT

$EXYNOS_CONTENT"
else
    FULL_REPLACEMENT="$EXYNOS_CONTENT"
fi

# 4. Replace the Exynos 3475 include section with the combined content
awk -v content="$FULL_REPLACEMENT" '
    /<!-- Exynos 3475 -->/ {
        # Read the next line which contains the <include ...> tag and discard both
        getline
        # Inject the inner contents
        print content
        next
    }
    { print }
' "$ROOMSERVICE" > "${ROOMSERVICE}.tmp" && mv "${ROOMSERVICE}.tmp" "$ROOMSERVICE"

echo "✅ Successfully generated and merged $ROOMSERVICE"

echo "🎉 Setup complete! You can now run: repo sync"
