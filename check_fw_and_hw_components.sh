#!/bin/bash

# Checks firmware and hardware component integrity

# Use the environment variable for output directory or fall back to default
OUT_DIR="${ANDROID_INTEGRITY_SESSION:-aisnapshots/tmp}/firmware"
mkdir -p "$OUT_DIR"

echo "[*] Checking firmware and hardware components..."

# Check if we have root access
if ! adb shell "id" | grep -q "uid=0"; then
    echo "[!] Root privileges required on ADB for full firmware checks"
    echo "[!] Please run 'adb root' before executing this script"
    exit 1
fi

# Gather device information
echo "Device Firmware and Hardware Report" > "$OUT_DIR/fw_hw_info.txt"
echo "----------------------------" >> "$OUT_DIR/fw_hw_info.txt"

# Collect bootloader information
echo "[*] Collecting bootloader information..."
echo -e "\n==== Bootloader Information ====" >> "$OUT_DIR/fw_hw_info.txt"
adb shell "getprop ro.bootloader" >> "$OUT_DIR/fw_hw_info.txt" 2>/dev/null
adb shell "getprop ro.boot.flash.locked" >> "$OUT_DIR/fw_hw_info.txt" 2>/dev/null
adb shell "getprop ro.boot.verifiedbootstate" >> "$OUT_DIR/fw_hw_info.txt" 2>/dev/null
adb shell "getprop ro.boot.veritymode" >> "$OUT_DIR/fw_hw_info.txt" 2>/dev/null
adb shell "getprop ro.boot.warranty_bit" >> "$OUT_DIR/fw_hw_info.txt" 2>/dev/null
adb shell "getprop ro.warranty_bit" >> "$OUT_DIR/fw_hw_info.txt" 2>/dev/null

# Collect security patch information
echo "[*] Collecting security patch information..."
echo -e "\n==== Security Information ====" >> "$OUT_DIR/fw_hw_info.txt"
echo "Security Patch Level: $(adb shell "getprop ro.build.version.security_patch")" >> "$OUT_DIR/fw_hw_info.txt"
echo "Vendor Security Patch Level: $(adb shell "getprop ro.vendor.build.security_patch")" >> "$OUT_DIR/fw_hw_info.txt"

# Collect hardware component information
echo "[*] Collecting hardware component information..."
echo -e "\n==== Hardware Components ====" >> "$OUT_DIR/fw_hw_info.txt"
adb shell "cat /proc/cpuinfo" > "$OUT_DIR/cpuinfo.txt"
echo "CPU Info saved to cpuinfo.txt" >> "$OUT_DIR/fw_hw_info.txt"

# Look for firmware and drivers
echo "[*] Checking firmware modules..."
echo -e "\n==== Loaded Firmware Modules ====" >> "$OUT_DIR/fw_hw_info.txt"
adb shell "lsmod" > "$OUT_DIR/loaded_modules.txt"
echo "Loaded modules saved to loaded_modules.txt" >> "$OUT_DIR/fw_hw_info.txt"

# Check for any firmware in /firmware or /vendor/firmware
echo "[*] Listing firmware files..."
echo -e "\n==== Firmware Files ====" >> "$OUT_DIR/fw_hw_info.txt"
adb shell "find /firmware /vendor/firmware -type f 2>/dev/null | sort" > "$OUT_DIR/firmware_files.txt"
echo "Firmware files list saved to firmware_files.txt" >> "$OUT_DIR/fw_hw_info.txt"

# Checking secure boot state
echo "[*] Checking secure boot state..."
echo -e "\n==== Secure Boot Status ====" >> "$OUT_DIR/fw_hw_info.txt"
adb shell "[ -e /sys/kernel/security/secure_boot ] && cat /sys/kernel/security/secure_boot || echo 'Secure boot information not available'" >> "$OUT_DIR/fw_hw_info.txt"

# Check verified boot state
echo "[*] Checking verified boot state..."
echo -e "\n==== Verified Boot Status ====" >> "$OUT_DIR/fw_hw_info.txt"
adb shell "getprop ro.boot.verifiedbootstate" >> "$OUT_DIR/fw_hw_info.txt"
adb shell "getprop ro.boot.flash.locked" >> "$OUT_DIR/fw_hw_info.txt"
adb shell "getprop ro.boot.vbmeta.device_state" >> "$OUT_DIR/fw_hw_info.txt"

echo "[✓] Firmware and hardware check complete"

# Generate hash index file
echo "[*] Generating hash index file..."
echo "File Hash Index - Firmware and Hardware Check" > "$OUT_DIR/hash_index.txt"
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