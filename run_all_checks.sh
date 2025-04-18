#!/bin/bash

# Android Advanced Threat Detection Framework
# Main executor script

# Base output directory
BASE_OUT_DIR="aisnapshots"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TMP_DIR="$BASE_OUT_DIR/tmp"
SNAP_DIR="$BASE_OUT_DIR/snap_$TIMESTAMP"

echo "[*] Android Integrity Snapshot Framework"
echo "[*] Starting comprehensive analysis..."

# Create temporary directory
mkdir -p "$TMP_DIR"

# Export the temporary directory for child scripts
export ANDROID_INTEGRITY_SNAP="$TMP_DIR"

# Define scripts to run with their module names
SCRIPTS=(
    "./check_base_partitions.sh:partitions"
    "./check_fw_and_hw_components.sh:firmware"
    "./check_tees.sh:tee"
    "./check_non_partioned_storage.sh:hidden_areas"
)

# Run all scripts and track their status
for SCRIPT_ITEM in "${SCRIPTS[@]}"; do
    # Split the script name and module name
    SCRIPT="${SCRIPT_ITEM%%:*}"
    NAME="${SCRIPT_ITEM#*:}"
    
    echo "[*] Running $NAME check..."
    
    # Create module directory
    mkdir -p "$TMP_DIR/$NAME"
    
    # Run the script
    if bash "$SCRIPT"; then
        echo "[✓] $NAME check completed successfully"
        echo "SUCCESS" > "$TMP_DIR/$NAME/status.txt"
    else
        echo "[!] $NAME check failed"
        echo "FAILED" > "$TMP_DIR/$NAME/status.txt"
    fi
done

# Generate summary report
echo "Android Device Integrity Check" > "$TMP_DIR/summary.txt"
echo "Run at: $(date)" >> "$TMP_DIR/summary.txt"
echo "----------------------------------------" >> "$TMP_DIR/summary.txt"
echo "Partitions check: $(cat "$TMP_DIR/partitions/status.txt" 2>/dev/null || echo 'NOT RUN')" >> "$TMP_DIR/summary.txt"
echo "Firmware check: $(cat "$TMP_DIR/firmware/status.txt" 2>/dev/null || echo 'NOT RUN')" >> "$TMP_DIR/summary.txt"
echo "TEE check: $(cat "$TMP_DIR/tee/status.txt" 2>/dev/null || echo 'NOT RUN')" >> "$TMP_DIR/summary.txt"
echo "Hidden areas check: $(cat "$TMP_DIR/hidden_areas/status.txt" 2>/dev/null || echo 'NOT RUN')" >> "$TMP_DIR/summary.txt"
echo "" >> "$TMP_DIR/summary.txt"

# Add detailed reports from each module
echo "========================================" >> "$TMP_DIR/summary.txt"
echo "DETAILED REPORTS FROM ALL MODULES" >> "$TMP_DIR/summary.txt"
echo "========================================" >> "$TMP_DIR/summary.txt"

# Function to concatenate text files from a module
concatenate_module_reports() {
    local module_dir="$1"
    local module_name="$2"
    
    if [ -d "$module_dir" ]; then
        echo "" >> "$TMP_DIR/summary.txt"
        echo "======== $module_name DETAILED REPORT ========" >> "$TMP_DIR/summary.txt"
        echo "" >> "$TMP_DIR/summary.txt"
        
        # Find all txt files except status.txt and concatenate them
        find "$module_dir" -name "*.txt" -not -name "status.txt" -type f | sort | while read -r file; do
            echo "--- $(basename "$file") ---" >> "$TMP_DIR/summary.txt"
            cat "$file" >> "$TMP_DIR/summary.txt"
            echo "" >> "$TMP_DIR/summary.txt"
        done
    fi
}

# Concatenate reports from each module
concatenate_module_reports "$TMP_DIR/partitions" "PARTITIONS"
concatenate_module_reports "$TMP_DIR/firmware" "FIRMWARE"
concatenate_module_reports "$TMP_DIR/tee" "TEE"
concatenate_module_reports "$TMP_DIR/hidden_areas" "HIDDEN AREAS"

# Rename the temporary directory to the timestamped session directory
mv "$TMP_DIR" "$SNAP_DIR"

echo "[✓] All checks completed!"
echo "[*] Results saved to: $SNAP_DIR"
echo "[*] Summary report available at: $SNAP_DIR/summary.txt"
echo ""
echo "Run this tool periodically and compare results to detect unauthorized changes."