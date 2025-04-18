#!/bin/bash

set -e

# Checks critical partitions

# Use the environment variable for output directory or fall back to default
OUT_DIR="${ANDROID_INTEGRITY_SESSION:-aisnapshots/tmp}/partitions"
mkdir -p "$OUT_DIR"
mkdir -p "$OUT_DIR/dumps"

echo "[*] Android Integrity Snapshot"
echo "[*] Searching for critical partitions that aren't changed in standard flashes..."

# Check if we have required binaries
if ! command -v adb &> /dev/null; then
    echo "[!] Required tool (adb) not found"
    exit 1
fi

# Check for root access
if ! adb shell "id" | grep -q "uid=0"; then
    echo "[!] Root privileges required on ADB to access partitions"
    echo "[!] Please run 'adb root' before executing this script"
    exit 1
fi

# Get device info
DEVICE_MODEL=$(adb shell "getprop ro.product.model" 2>/dev/null || echo "Unknown")
ANDROID_VER=$(adb shell "getprop ro.build.version.release" 2>/dev/null || echo "Unknown")
FINGERPRINT=$(adb shell "getprop ro.build.fingerprint" 2>/dev/null || echo "Unknown")

# Save device info
echo "Device: $DEVICE_MODEL" > "$OUT_DIR/device_info.txt"
echo "Android: $ANDROID_VER" >> "$OUT_DIR/device_info.txt"
echo "Build: $FINGERPRINT" >> "$OUT_DIR/device_info.txt"

echo "[*] Identifying block device partitions..."
# Try different approaches to find partitions as devices have different paths
if ! adb shell "ls -la /dev/block/platform/*/by-name/" > "$OUT_DIR/partition_list.txt" 2>/dev/null; then
    # Try alternative paths if the first approach fails
    if ! adb shell "ls -la /dev/block/bootdevice/by-name/" > "$OUT_DIR/partition_list.txt" 2>/dev/null; then
        # Try a more generic search for partition links
        adb shell "find /dev/block -name by-name -type d -exec ls -la {} \;" > "$OUT_DIR/partition_list.txt" 2>/dev/null || 
        echo "[!] Warning: Could not list partitions using standard methods. Partition detection may be incomplete." | tee -a "$OUT_DIR/partition_list.txt"
    fi
fi

# List of partitions that are typically not modified in a ROM flash
# These are partitions that usually contain persistent or critical system data
PARTITIONS_TO_CHECK=(
    "persist"
    "ssd"
    "frp"
    "metadata"
    "misc"
    "modemst1"
    "modemst2"
    "fsc"
    "bluetooth_a"
    "dsp_a"
    "abl_a"
    "aop_a"
    "boot_a"
    "devcfg_a"
    "dtbo_a"
    "hyp_a"
    "keymaster_a"
    "modem_a"
    "prov_a"
    "qupfw_a"
    "storsec_a"
    "tz_a"
    "uefisecapp_a"
    "vbmeta_a"
    "vbmeta_system_a"
    "xbl_a"
    "xbl_config_a"
    "recovery_a"
    "carrier"
    "devinfo"
    "fsg_a"
)

echo "[*] Starting dump and hash calculation of critical partitions..."

# Create report file
echo "Partition Hash Report" > "$OUT_DIR/partition_hashes.txt"
echo "----------------------------" >> "$OUT_DIR/partition_hashes.txt"

for PART in "${PARTITIONS_TO_CHECK[@]}"; do
    # Check if partition exists on the device
    if ! adb shell "[ -e /dev/block/by-name/${PART} ]" &>/dev/null; then
        echo "[!] Partition $PART not found at /dev/block/by-name/. Trying direct path..."
        
        # Try to use direct path from the list
        if ! adb shell "[ -e /dev/block/by-name/${PART} ]" &>/dev/null; then
            echo "[!] Partition $PART not found on this device. Skipping..."
            echo "$PART: NOT FOUND" >> "$OUT_DIR/partition_hashes.txt"
            continue
        fi
    fi

    echo "[+] Checking critical partition: $PART"
    
    # Define local filename
    OUT_FILE="$OUT_DIR/dumps/${PART}.img"

    # Realpath of partition on device
    BLOCK_PATH=$(adb shell "realpath /dev/block/by-name/$PART" | tr -d '\r')

    if [[ -z "$BLOCK_PATH" ]]; then
        echo "[!] Path not found for $PART. Skipping..."
        echo "$PART: PATH NOT FOUND" >> "$OUT_DIR/partition_hashes.txt"
        continue
    fi

    # Dump the full partition (no size limit)
    echo "[+] Dumping full partition $PART ($BLOCK_PATH)"
    if adb shell "dd if=$BLOCK_PATH" > "$OUT_FILE" 2>/dev/null; then
        HASH=$(sha256sum "$OUT_FILE" | awk '{print $1}')
        echo "$PART: $HASH" >> "$OUT_DIR/partition_hashes.txt"
        echo "[✓] Hash calculated for $PART: ${HASH:0:16}..."
    else
        echo "[!] Error dumping $PART. Skipping..."
        echo "$PART: ERROR DUMPING" >> "$OUT_DIR/partition_hashes.txt"
    fi
done

echo "[*] Checking for non-standard partitions..."
adb shell "find /dev/block/platform -type l | grep -v -E '$(echo "${PARTITIONS_TO_CHECK[@]}" | tr ' ' '|')'" > "$OUT_DIR/nonstandard_partitions.txt"

echo "[✔] Verification complete. Files saved in '$OUT_DIR'."
echo "[*] Run this script periodically and compare hashes to detect suspicious changes."
echo "[*] Changes in hashes may indicate system compromise or APT attack."

# Generate hash index file
echo "[*] Generating hash index file..."
echo "File Hash Index - Base Partitions Check" > "$OUT_DIR/hash_index.txt"
echo "----------------------------" >> "$OUT_DIR/hash_index.txt"

# Calculate hashes for all generated text files
for file in "$OUT_DIR"/*.txt; do
    if [ -f "$file" ] && [ "$(basename "$file")" != "hash_index.txt" ]; then
        filename=$(basename "$file")
        filehash=$(sha256sum "$file" | awk '{print $1}')
        echo "$filename: $filehash" >> "$OUT_DIR/hash_index.txt"
    fi
done

# O hash_index não deve mais incluir hashes das imagens dos dumps
# Apenas os arquivos de texto (relatórios) serão considerados

echo "[✓] Hash index generated"
exit 0

