#!/bin/bash

# Checks Trusted Execution Environment components

# Use the environment variable for output directory or fall back to default
OUT_DIR="${ANDROID_INTEGRITY_SESSION:-aisnapshots/tmp}/tee"
mkdir -p "$OUT_DIR"

echo "[*] Checking TEE (Trusted Execution Environment) integrity..."

# Check if we have root access
if ! adb shell "id" | grep -q "uid=0"; then
    echo "[!] Root privileges required on ADB for TEE checks"
    echo "[!] Please run 'adb root' before executing this script"
    exit 1
fi

# Gather TEE information
echo "Trusted Execution Environment Analysis" > "$OUT_DIR/tee_report.txt"
echo "----------------------------" >> "$OUT_DIR/tee_report.txt"

# Check for Qualcomm/QSEE
echo "[*] Checking for Qualcomm Secure Execution Environment (QSEE)..."
adb shell "[ -e /dev/qseecom ] && echo 'QSEE detected (/dev/qseecom exists)' || echo 'QSEE not detected'" >> "$OUT_DIR/tee_report.txt"
adb shell "[ -e /dev/qseecom ] && ls -la /dev/qseecom" >> "$OUT_DIR/tee_report.txt"

# Check for Samsung TEE (Kinibi/Mobicore/Teegris)
echo "[*] Checking for Samsung TEE components..."
for TEE_DEV in "mobicore" "t-base-tui" "teegris"; do
    adb shell "[ -e /dev/$TEE_DEV ] && echo 'Samsung TEE detected (/dev/$TEE_DEV exists)' && ls -la /dev/$TEE_DEV" >> "$OUT_DIR/tee_report.txt"
done

# Check for Trustonic TEE
echo "[*] Checking for Trustonic TEE..."
adb shell "[ -e /dev/t-base-tui -o -e /dev/mobicore ] && echo 'Trustonic TEE detected'" >> "$OUT_DIR/tee_report.txt"

# Check for Trusted Firmware files
echo "[*] Checking for TEE firmware files..."
echo -e "\n==== TEE Firmware Files ====" >> "$OUT_DIR/tee_report.txt"

# Common firmware locations
TEE_FIRMWARE_DIRS=(
    "/vendor/firmware"
    "/vendor/firmware_mnt"
    "/firmware"
    "/system/vendor/firmware"
)

# Common TEE firmware file patterns
TEE_FIRMWARE_PATTERNS=(
    "*trustlet*"
    "*tzapp*"
    "*trustzone*"
    "*tz*"
    "*tee*"
    "*mobicore*"
    "*mcRegistry*"
    "*qsee*"
    "*keymaster*"
    "*cmnlib*"
    "*secure*"
)

for DIR in "${TEE_FIRMWARE_DIRS[@]}"; do
    adb shell "[ -d $DIR ] && echo 'Checking directory: $DIR'" >> "$OUT_DIR/tee_report.txt"
    for PATTERN in "${TEE_FIRMWARE_PATTERNS[@]}"; do
        adb shell "find $DIR -name '$PATTERN' 2>/dev/null" >> "$OUT_DIR/tee_firmware_files.txt"
    done
done

if [ -s "$OUT_DIR/tee_firmware_files.txt" ]; then
    echo "TEE firmware files found - see tee_firmware_files.txt" >> "$OUT_DIR/tee_report.txt"
    cat "$OUT_DIR/tee_firmware_files.txt" | sort | uniq >> "$OUT_DIR/tee_report.txt"
else
    echo "No TEE firmware files found" >> "$OUT_DIR/tee_report.txt"
fi

# Extract TEE version information
echo "[*] Attempting to extract TEE version information..."
echo -e "\n==== TEE Version Information ====" >> "$OUT_DIR/tee_report.txt"

# Try to get TEE properties from Android
adb shell "getprop | grep -i 'tee\|trustzone\|qsee\|keymaster'" > "$OUT_DIR/tee_properties.txt"
if [ -s "$OUT_DIR/tee_properties.txt" ]; then
    echo "TEE properties found in system properties:" >> "$OUT_DIR/tee_report.txt"
    cat "$OUT_DIR/tee_properties.txt" >> "$OUT_DIR/tee_report.txt"
else
    echo "No TEE properties found in system properties" >> "$OUT_DIR/tee_report.txt"
fi

echo "[✓] TEE check complete"

# Generate hash index file
echo "[*] Generating hash index file..."
echo "File Hash Index - TEE Check" > "$OUT_DIR/hash_index.txt"
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