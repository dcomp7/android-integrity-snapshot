#!/bin/bash

# Snapshot comparison tool

BASE_DIR="aisnapshots"
REPORT_DIR="reports"
TEMPLATE_DIR="llm_prompt_template"

# Function to print usage information
function print_usage() {
    echo "Usage: $0 [snapshot1_dir] [snapshot2_dir]"
    echo "  If no arguments provided, the two most recent snapshots will be compared"
    echo "  snapshot1_dir, snapshot2_dir: Optional paths to snapshot directories"
    echo ""
    echo "Example: $0 $BASE_DIR/snap_20230101_120000 $BASE_DIR/snap_20230102_120000"
}

# Function to find the two most recent snapshot directories
function find_recent_snapshots() {
    find "$BASE_DIR" -maxdepth 1 -type d -name "snap_*" | sort -r | head -n 2
}

# Check if we have directory arguments or need to find the most recent
if [ $# -eq 2 ]; then
    # Use provided directories
    SNAP1="$1"
    SNAP2="$2"
    
    # Validate provided directories
    if [ ! -d "$SNAP1" ]; then
        echo "[!] Error: Directory not found: $SNAP1"
        exit 1
    fi
    
    if [ ! -d "$SNAP2" ]; then
        echo "[!] Error: Directory not found: $SNAP2"
        exit 1
    fi
elif [ $# -eq 0 ]; then
    # Find the two most recent snapshots
    SNAPSHOTS=($(find_recent_snapshots))
    
    if [ ${#SNAPSHOTS[@]} -lt 2 ]; then
        echo "[!] Error: Could not find at least two snapshot directories in $BASE_DIR"
        echo "    Please run the snapshot tool at least twice before comparison"
        exit 1
    fi
    
    SNAP1="${SNAPSHOTS[0]}"
    SNAP2="${SNAPSHOTS[1]}"
    echo "[*] Comparing most recent snapshots:"
    echo "    - $SNAP1 (newer)"
    echo "    - $SNAP2 (older)"
else
    print_usage
    exit 1
fi

# Create report directory
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
COMPARE_DIR="$BASE_DIR/$REPORT_DIR/compare_${TIMESTAMP}"
mkdir -p "$COMPARE_DIR"

# Extract snapshot timestamps from directory names
SNAP1_NAME=$(basename "$SNAP1")
SNAP2_NAME=$(basename "$SNAP2")

echo "[*] Android Integrity Snapshot Comparison"
echo "[*] Comparing $SNAP1_NAME (newer) with $SNAP2_NAME (older)"
echo "[*] Generating report in $COMPARE_DIR"

# Initialize counters for change statistics
total_files=0
total_new_files=0
total_changed_files=0
total_deleted_files=0
total_modules_with_changes=0
total_modules=0
changed_modules=()

# Create summary file
echo "Android Integrity Snapshot Comparison" > "$COMPARE_DIR/report.txt"
echo "Comparing:" >> "$COMPARE_DIR/report.txt"
echo "  - $SNAP1_NAME (newer)" >> "$COMPARE_DIR/report.txt"
echo "  - $SNAP2_NAME (older)" >> "$COMPARE_DIR/report.txt"
echo "Generated at: $(date)" >> "$COMPARE_DIR/report.txt"
echo "----------------------------------------" >> "$COMPARE_DIR/report.txt"

# Modules to compare (must match directory names in snapshots)
MODULES=("partitions" "firmware" "tee" "hidden_areas")

# For each module, find and compare text files
for MODULE in "${MODULES[@]}"; do
    # Create module directory in report
    mkdir -p "$COMPARE_DIR/$MODULE"
    
    echo "[*] Processing $MODULE module..."
    echo "== $MODULE Module ==" >> "$COMPARE_DIR/report.txt"
    
    # Initialize module-specific counters
    module_new_files=0
    module_changed_files=0
    module_deleted_files=0
    module_files=0
    
    # Check if module exists in both snapshots
    if [ ! -d "$SNAP1/$MODULE" ] || [ ! -d "$SNAP2/$MODULE" ]; then
        echo "[!] Module $MODULE missing in one of the snapshots, skipping"
        echo "  Module missing in one snapshot, skipping" >> "$COMPARE_DIR/report.txt"
        continue
    fi
    
    total_modules=$((total_modules + 1))
    
    # Find all *.txt files in the newer snapshot for this module
    TXT_FILES=$(find "$SNAP1/$MODULE" -type f -name "*.txt" | sort)
    
    # Track changes for this module
    CHANGES_FOUND=0
    
    # Compare each txt file
    for FILE in $TXT_FILES; do
        FILENAME=$(basename "$FILE")
        RELATIVE_PATH="${MODULE}/${FILENAME}"
        OLDER_FILE="$SNAP2/$RELATIVE_PATH"
        
        # Increment total files counter
        total_files=$((total_files + 1))
        module_files=$((module_files + 1))
        
        # Skip hash_index.txt since it's expected to change
        if [[ "$FILENAME" == "hash_index.txt" ]]; then
            continue
        fi
        
        # Check if the file exists in the older snapshot
        if [ ! -f "$OLDER_FILE" ]; then
            echo "[!] File $FILENAME is new in the latest snapshot"
            echo "  NEW FILE: $FILENAME" >> "$COMPARE_DIR/report.txt"
            cp "$FILE" "$COMPARE_DIR/$RELATIVE_PATH.new"
            CHANGES_FOUND=1
            total_new_files=$((total_new_files + 1))
            module_new_files=$((module_new_files + 1))
            continue
        fi
        
        # Compare the files
        if ! diff -q "$FILE" "$OLDER_FILE" > /dev/null; then
            echo "[!] Changes detected in $FILENAME"
            # Get diff stats
            DIFF_STATS=$(diff -u "$OLDER_FILE" "$FILE" | grep -e "^+" -e "^-" | wc -l)
            echo "  CHANGED: $FILENAME (${DIFF_STATS} line changes)" >> "$COMPARE_DIR/report.txt"
            # Create a diff file
            diff -u "$OLDER_FILE" "$FILE" > "$COMPARE_DIR/$RELATIVE_PATH.diff"
            CHANGES_FOUND=1
            total_changed_files=$((total_changed_files + 1))
            module_changed_files=$((module_changed_files + 1))
        fi
    done
    
    # Check for deleted files
    for OLDER_FILE in $(find "$SNAP2/$MODULE" -type f -name "*.txt" | sort); do
        FILENAME=$(basename "$OLDER_FILE")
        RELATIVE_PATH="${MODULE}/${FILENAME}"
        NEWER_FILE="$SNAP1/$RELATIVE_PATH"
        
        # Skip hash_index.txt
        if [[ "$FILENAME" == "hash_index.txt" ]]; then
            continue
        fi
        
        # Check if the file exists in the newer snapshot
        if [ ! -f "$NEWER_FILE" ]; then
            echo "[!] File $FILENAME was deleted in the latest snapshot"
            echo "  DELETED: $FILENAME" >> "$COMPARE_DIR/report.txt"
            cp "$OLDER_FILE" "$COMPARE_DIR/$RELATIVE_PATH.deleted"
            CHANGES_FOUND=1
            total_deleted_files=$((total_deleted_files + 1))
            module_deleted_files=$((module_deleted_files + 1))
        fi
    done
    
    # If changes were found, add to module counts
    if [ $CHANGES_FOUND -eq 1 ]; then
        total_modules_with_changes=$((total_modules_with_changes + 1))
        changed_modules+=("$MODULE")
        echo "  Module Statistics:" >> "$COMPARE_DIR/report.txt"
        echo "    - Total files: $module_files" >> "$COMPARE_DIR/report.txt"
        echo "    - New files: $module_new_files" >> "$COMPARE_DIR/report.txt"
        echo "    - Changed files: $module_changed_files" >> "$COMPARE_DIR/report.txt"
        echo "    - Deleted files: $module_deleted_files" >> "$COMPARE_DIR/report.txt"
    fi
    
    # If no changes found for this module, note it in the summary
    if [ $CHANGES_FOUND -eq 0 ]; then
        echo "[✓] No changes detected in $MODULE"
        echo "  No changes detected" >> "$COMPARE_DIR/report.txt"
    fi
    
    echo "" >> "$COMPARE_DIR/report.txt"
done

# Compare partition hashes specifically
echo "[*] Checking partition hashes specifically..."
echo "== Partition Hashes Comparison ==" >> "$COMPARE_DIR/report.txt"

PARTITION_HASH_FILE1="$SNAP1/partitions/partition_hashes.txt"
PARTITION_HASH_FILE2="$SNAP2/partitions/partition_hashes.txt"

partition_new=0
partition_changed=0
partition_removed=0

if [ -f "$PARTITION_HASH_FILE1" ] && [ -f "$PARTITION_HASH_FILE2" ]; then
    # Create partition hashes directory
    mkdir -p "$COMPARE_DIR/partition_hashes"
    
    # Parse both hash files and compare partitions
    PARTITION_CHANGES=0
    
    # Process partition hash files line by line
    while IFS=': ' read -r PARTITION HASH || [[ -n "$PARTITION" ]]; do
        # Skip header lines
        if [[ "$PARTITION" == *"Partition Hash Report"* ]] || [[ "$PARTITION" == *"Generated"* ]] || [[ "$PARTITION" == *"----"* ]]; then
            continue
        fi
        
        # Find the same partition in the older file
        OLD_HASH=$(grep "^$PARTITION:" "$PARTITION_HASH_FILE2" | cut -d ' ' -f 2-)
        
        # If partition exists in both, compare hashes
        if [ -n "$OLD_HASH" ]; then
            if [ "$HASH" != "$OLD_HASH" ]; then
                echo "[!] Partition $PARTITION has changed hash!"
                echo "  CHANGED HASH: $PARTITION" >> "$COMPARE_DIR/report.txt"
                echo "Partition: $PARTITION" > "$COMPARE_DIR/partition_hashes/${PARTITION}.change"
                echo "Old hash: $OLD_HASH" >> "$COMPARE_DIR/partition_hashes/${PARTITION}.change"
                echo "New hash: $HASH" >> "$COMPARE_DIR/partition_hashes/${PARTITION}.change"
                PARTITION_CHANGES=1
                partition_changed=$((partition_changed + 1))
            fi
        else
            echo "[!] Partition $PARTITION is new in the latest snapshot"
            echo "  NEW PARTITION: $PARTITION" >> "$COMPARE_DIR/report.txt"
            PARTITION_CHANGES=1
            partition_new=$((partition_new + 1))
        fi
    done < "$PARTITION_HASH_FILE1"
    
    # Check for partitions that have been removed
    while IFS=': ' read -r PARTITION HASH || [[ -n "$PARTITION" ]]; do
        # Skip header lines
        if [[ "$PARTITION" == *"Partition Hash Report"* ]] || [[ "$PARTITION" == *"Generated"* ]] || [[ "$PARTITION" == *"----"* ]]; then
            continue
        fi
        
        # Check if partition exists in newer file
        if ! grep -q "^$PARTITION:" "$PARTITION_HASH_FILE1"; then
            echo "[!] Partition $PARTITION was removed in the latest snapshot"
            echo "  REMOVED PARTITION: $PARTITION" >> "$COMPARE_DIR/report.txt"
            PARTITION_CHANGES=1
            partition_removed=$((partition_removed + 1))
        fi
    done < "$PARTITION_HASH_FILE2"
    
    if [ $PARTITION_CHANGES -eq 0 ]; then
        echo "[✓] No changes detected in partition hashes"
        echo "  No changes detected in partition hashes" >> "$COMPARE_DIR/report.txt"
    else
        echo "  Partition Statistics:" >> "$COMPARE_DIR/report.txt"
        echo "    - New partitions: $partition_new" >> "$COMPARE_DIR/report.txt"
        echo "    - Changed partitions: $partition_changed" >> "$COMPARE_DIR/report.txt"
        echo "    - Removed partitions: $partition_removed" >> "$COMPARE_DIR/report.txt"
    fi
else
    echo "[!] Partition hash files not found in one or both snapshots"
    echo "  Partition hash files not found in one or both snapshots" >> "$COMPARE_DIR/report.txt"
fi

# Add summary to the beginning of the report
SUMMARY="## SUMMARY REPORT\n"
SUMMARY+="Snapshots compared: $SNAP1_NAME (newer) vs $SNAP2_NAME (older)\n"
SUMMARY+="Comparison timestamp: $(date)\n\n"
SUMMARY+="Total modules analyzed: $total_modules\n"
SUMMARY+="Modules with changes: $total_modules_with_changes\n"
if [ $total_modules_with_changes -gt 0 ]; then
    SUMMARY+="Changed modules: ${changed_modules[*]}\n"
fi
SUMMARY+="\nFile statistics:\n"
SUMMARY+="  - Total files analyzed: $total_files\n"
SUMMARY+="  - New files: $total_new_files\n"
SUMMARY+="  - Changed files: $total_changed_files\n"
SUMMARY+="  - Deleted files: $total_deleted_files\n"
SUMMARY+="  - Total changes: $((total_new_files + total_changed_files + total_deleted_files))\n"
SUMMARY+="\nPartition statistics:\n"
SUMMARY+="  - New partitions: $partition_new\n"
SUMMARY+="  - Changed partitions: $partition_changed\n"
SUMMARY+="  - Removed partitions: $partition_removed\n"
SUMMARY+="  - Total partition changes: $((partition_new + partition_changed + partition_removed))\n\n"

if [ $total_modules_with_changes -eq 0 ] && [ $((partition_new + partition_changed + partition_removed)) -eq 0 ]; then
    SUMMARY+="OVERALL STATUS: No changes detected\n"
else
    SUMMARY+="OVERALL STATUS: Changes detected\n"
fi
SUMMARY+="----------------------------------------\n\n"

# Insert summary at the beginning of the report
TEMP_REPORT=$(mktemp)
echo -e "$SUMMARY" > "$TEMP_REPORT"
cat "$COMPARE_DIR/report.txt" >> "$TEMP_REPORT"
mv "$TEMP_REPORT" "$COMPARE_DIR/report.txt"

echo "[✓] Comparison complete!"
echo "[*] Report generated in $COMPARE_DIR"
echo "[*] Summary file: $COMPARE_DIR/report.txt"

# Create the prompt_to_analyse.txt file
if [ -f "initial_prompt.txt" ]; then
    echo "[*] Creating AI analysis prompt file..."
    
    # Start with the template
    cp "$TEMPLATE_DIR/initial_prompt.txt" "$COMPARE_DIR/prompt_to_analyse.txt"
    
    # Add device information if available
    if [ -f "$SNAP1/device_info.txt" ]; then
        echo -e "\n### DEVICE INFORMATION ###" >> "$COMPARE_DIR/prompt_to_analyse.txt"
        cat "$SNAP1/device_info.txt" >> "$COMPARE_DIR/prompt_to_analyse.txt"
    fi
    
    # Add the report
    echo -e "\n### COMPARISON REPORT ###" >> "$COMPARE_DIR/prompt_to_analyse.txt"
    cat "$COMPARE_DIR/report.txt" >> "$COMPARE_DIR/prompt_to_analyse.txt"
    
    echo "[*] AI analysis prompt created: $COMPARE_DIR/prompt_to_analyse.txt"
    
    # Ask if user wants to send to ChatGPT
    echo ""
    read -p "Would you like to send this report to ChatGPT for analysis? (y/n): " SEND_TO_GPT
    
    if [[ "$SEND_TO_GPT" =~ ^[Yy]$ ]]; then
        read -p "Please enter your OpenAI API key: " OPENAI_API_KEY
        
        if [ -n "$OPENAI_API_KEY" ]; then
            echo "[*] Sending report to ChatGPT for analysis..."
            
            # Get the content of the prompt file
            PROMPT_CONTENT=$(cat "$COMPARE_DIR/prompt_to_analyse.txt")
            
            # Prepare API request
            API_RESPONSE=$(curl -s https://api.openai.com/v1/chat/completions \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $OPENAI_API_KEY" \
                -d "{
                    \"model\": \"gpt-4\",
                    \"messages\": [{\"role\": \"user\", \"content\": \"$PROMPT_CONTENT\"}],
                    \"temperature\": 0.7
                }")
            
            # Extract and display the response
            GPT_RESPONSE=$(echo "$API_RESPONSE" | grep -o '"content":"[^"]*"' | sed 's/"content":"//;s/"$//')
            
            if [ -n "$GPT_RESPONSE" ]; then
                echo ""
                echo "====== AI ANALYSIS REPORT ======"
                echo ""
                echo -e "$GPT_RESPONSE" | sed 's/\\n/\n/g'
                echo ""
                echo "==============================="
                
                # Save the response to a file
                echo -e "$GPT_RESPONSE" | sed 's/\\n/\n/g' > "$COMPARE_DIR/ai_analysis.txt"
                echo "[*] AI analysis saved to: $COMPARE_DIR/ai_analysis.txt"
            else
                echo "[!] Error: Failed to get a response from ChatGPT API"
                echo "API Response: $API_RESPONSE"
            fi
        else
            echo "[!] No API key provided. Skipping ChatGPT analysis."
        fi
    else
        echo "[*] Skipping ChatGPT analysis."
    fi
else
    echo "[!] Warning: Template file initial_prompt.txt not found"
    echo "    Cannot create AI analysis prompt"
fi

exit 0