# Local Manifests for Exynos 3475 Devices

This repository contains the local manifests required to initialize and sync the device-specific trees for building LineageOS on Samsung Exynos 3475 devices.

## Supported Devices
- **Samsung Galaxy J2 2015 (`j2lte`)**: `j2lte.xml`
- **Samsung Galaxy J1 2016 (`j1xlte`)**: `j1xlte.xml`
- **Samsung Galaxy On5 (`on5ltetmo`)**: `on5ltetmo.xml`

---

## Step-by-Step Build Setup

### 1. Initialize the Source Tree
Create and navigate to your workspace directory:
```bash
mkdir lineage-<version>   # Replace <version> with your LineageOS version (e.g., 17.1)
cd lineage-<version>
```

### 2. Initialize the Base Source Code
Initialize the LineageOS repository manifest:
```bash
repo init -u https://github.com/LineageOS/android -b lineage-<version>   # Replace <version> with your target version (e.g., 17.1)
```

### 3. Add the Local Manifests
You can use the remote execution script, the local setup script, or copy the files manually.

#### Option A: Remote Execution (Recommended)
Run the setup script directly from the remote repository without cloning it by running this command from the root of your LineageOS source tree:
```bash
bash <(curl -sf https://raw.githubusercontent.com/samsungexynos3475/local_manifests/main/setup.sh) <version> j2lte
```
*(Replace `<version>` with your LineageOS version (e.g., `17.1`). You can specify one or more devices separated by spaces, e.g., `j2lte j1xlte on5ltetmo`)*

#### Option B: Local Setup Script
If you have cloned this repository, generate the manifest by running:
```bash
./local_manifests/setup.sh <version> j2lte j1xlte
```

#### Option C: Manual Configuration
The setup script will automatically generate a single, clean `roomservices.xml` file by cleanly merging the device manifests and the common `exynos3475.xml`. Doing this manually is no longer recommended.

### 4. Sync Source Code
Sync the repository (this will pull the base source code along with the device-specific repos defined in the local manifest):
```bash
repo sync --force-sync -q
```

### 5. Apply Essential Hardware Patches
Run the patch script from the root of your source directory to apply critical fixes for video recording, camera metadata, and Bluetooth service startup:
```bash
bash <(curl -sf https://raw.githubusercontent.com/samsungexynos3475/android_patches/main/patch.sh) <version>  # Replace <version> with your LineageOS version (e.g., 17.1)
```

### 6. Build from Source
Set up the environment, target your device, and start the build:
```bash
. build/envsetup.sh
lunch lineage_<DEVICE>-userdebug  # Replace <DEVICE> with j2lte, j1xlte, or on5ltetmo
mka bacon
```
