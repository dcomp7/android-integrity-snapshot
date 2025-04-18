#!/bin/bash

# Checks for non-partitioned storage areas that might hide malware

# Use the environment variable for output directory or fall back to default
OUT_DIR="${ANDROID_INTEGRITY_SESSION:-aisnapshots/tmp}/hidden_areas"
mkdir -p "$OUT_DIR"

echo "[*] Checking for hidden storage areas and artifacts..."

# Check if we have root access
if ! adb shell "id" | grep -q "uid=0"; then
    echo "[!] Root privileges required on ADB for hidden storage checks"
    echo "[!] Please run 'adb root' before executing this script"
    exit 1
fi

# Create the report file
echo "Hidden Storage Areas Check" > "$OUT_DIR/hidden_storage_report.txt"
echo "----------------------------" >> "$OUT_DIR/hidden_storage_report.txt"

# Check for persistent hidden storage in RPMB (Replay Protected Memory Block)
echo "[*] Checking for RPMB access points..."
echo -e "\n==== RPMB Storage ====" >> "$OUT_DIR/hidden_storage_report.txt"
adb shell "find /dev -name \"*rpmb*\" 2>/dev/null" >> "$OUT_DIR/hidden_storage_report.txt"

# Check for UFS storage areas
echo "[*] Checking for UFS hidden storage areas..."
echo -e "\n==== UFS Storage Areas ====" >> "$OUT_DIR/hidden_storage_report.txt"
adb shell "find /dev -name \"*ufs*\" 2>/dev/null" >> "$OUT_DIR/hidden_storage_report.txt"

# Check for eMMC boot partitions that can be used for hiding data
echo "[*] Checking for eMMC boot partitions..."
echo -e "\n==== eMMC Boot Partitions ====" >> "$OUT_DIR/hidden_storage_report.txt"
adb shell "find /dev -name \"*boot*\" | grep -i \"emmc\|mmc\" 2>/dev/null" >> "$OUT_DIR/hidden_storage_report.txt"

# Look for unusual block devices
echo "[*] Checking for unusual block devices..."
echo -e "\n==== Unusual Block Devices ====" >> "$OUT_DIR/hidden_storage_report.txt"
adb shell "ls -la /dev/block/" > "$OUT_DIR/block_devices.txt"
echo "Block devices listed in block_devices.txt" >> "$OUT_DIR/hidden_storage_report.txt"

# Check for unusual mount points
echo "[*] Checking for unusual mount points..."
echo -e "\n==== Unusual Mount Points ====" >> "$OUT_DIR/hidden_storage_report.txt"
adb shell "mount" > "$OUT_DIR/mount_points.txt"
echo "Mount points listed in mount_points.txt" >> "$OUT_DIR/hidden_storage_report.txt"

# Check raw access to NAND
echo "[*] Checking for raw NAND access points..."
echo -e "\n==== Raw NAND Access ====" >> "$OUT_DIR/hidden_storage_report.txt"
adb shell "find /dev -name \"*nand*\" 2>/dev/null" >> "$OUT_DIR/hidden_storage_report.txt"

# Look for unusual raw device access points
echo "[*] Checking for unusual raw device interfaces..."
echo -e "\n==== Unusual Raw Devices ====" >> "$OUT_DIR/hidden_storage_report.txt"
adb shell "ls -la /dev/raw* 2>/dev/null" >> "$OUT_DIR/hidden_storage_report.txt"

# Check for hidden partitions
echo "[*] Checking for potentially hidden partitions..."
echo -e "\n==== Potentially Hidden Partitions ====" >> "$OUT_DIR/hidden_storage_report.txt"
adb shell "ls -la /dev/block/mmcblk*rpmb 2>/dev/null" >> "$OUT_DIR/hidden_storage_report.txt"
adb shell "ls -la /dev/block/mmcblk*boot* 2>/dev/null" >> "$OUT_DIR/hidden_storage_report.txt"

# Check for unusual files in /dev
echo "[*] Checking for unusual files in /dev..."
echo -e "\n==== Unusual Files in /dev ====" >> "$OUT_DIR/hidden_storage_report.txt"
adb shell "find /dev -type f -size +0 2>/dev/null" >> "$OUT_DIR/hidden_storage_report.txt"

echo "[✓] Hidden storage areas check complete"

# Generate hash index file
echo "[*] Generating hash index file..."
echo "File Hash Index - Hidden Storage Check" > "$OUT_DIR/hash_index.txt"
echo "----------------------------" >> "$OUT_DIR/hash_index.txt"

# Calculate hashes for all generated files
for file in "$OUT_DIR"/*.txt; do
    if [ -f "$file" ] && [ "$(basename "$file")" != "hash_index.txt" ]; then
        filename=$(basename "$file")
        filehash=$(sha256sum "$file" | awk '{print $1}')
        echo "$filename: $filehash" >> "$OUT_DIR/hash_index.txt"
    fi
done

echo "[✓] Hash index generated"
exit 0