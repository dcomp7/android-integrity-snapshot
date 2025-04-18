# Android Integrity Snapshot 

## Overview

Android Integrity Snapshot is an experimental tool for retrieving the state of some low-level Android configurations and components, especially those that cannot be easily overwritten during the normal process of flashing a stock ROM or custom ROM.

This process is important to assist/support the detection of possible APT-type malware, which have advanced stealth capabilities and can survive factory flashes by lodging themselves in low-level areas of Android.

It is a tool with certain limitations, as a truly advanced APT could intercept and falsify the detection method proposed here. However, it is interesting to have a snapshot of the hashes of these partitions that are not easily altered.

**WARNING: This is an experimental tool and should be used only for educational and security research purposes.**

## Features

The tool consists of several specialized modules that analyze different critical aspects of the Android system:

1. **Partition Verification** - Monitors critical partitions that are not normally modified during standard firmware updates, allowing detection of rootkits and malicious modifications.

2. **Firmware Verification** - Examines bootloader, security patches, loaded firmware modules, and firmware files in the system, helping to identify modifications in firmware components.

3. **TEE (Trusted Execution Environment) Verification** - Validates the integrity of the secure execution environment, where cryptographic operations and sensitive credentials are processed.

4. **Hidden Areas Verification** - Searches for non-partitioned or hidden storage areas that can be used to hide persistent malware.

5. **Comparison Analysis** - Compares snapshots captured at different times and generates detailed reports of the changes found.

6. **AI Analysis** - Allows sending comparison reports to language models (such as GPT-4) for analysis and recommendations.

## Requirements

- Linux or MacOS system
- ADB (Android Debug Bridge) installed and configurable
- Root access (ADB) on the target Android device (standard in Lineage OS)
- Command-line tools: bash, curl, jq
- Internet connection (optional, only for AI analysis)

## How to Use

### Creating a Snapshot

```bash
./run_all_checks.sh
```

This command will create a complete snapshot of the device and store the results in a timestamped directory inside the `aisnapshots/` folder.

### Comparing Snapshots

```bash
./compare_snapshots.sh
```

Without arguments, the script will automatically compare the two most recent snapshots.

Alternatively, you can specify two snapshot directories:

```bash
./compare_snapshots.sh aisnapshots/snap_20230101_120000 aisnapshots/snap_20230102_120000
```

## Project Structure

- `run_all_checks.sh` - Main script that runs all modules and generates a complete snapshot
- `check_base_partitions.sh` - Checks critical system partitions
- `check_fw_and_hw_components.sh` - Analyzes firmware and hardware components
- `check_tees.sh` - Verifies the Trusted Execution Environment
- `check_non_partioned_storage.sh` - Searches for hidden storage areas
- `compare_snapshots.sh` - Compares snapshots and generates detailed reports
- `initial_prompt.txt` - Template for analysis prompts with language models

## Interpreting the Results

Comparison reports indicate files and partitions that were:
- Added (NEW)
- Modified (CHANGED)
- Deleted (DELETED)

Legitimate changes can occur due to normal system updates, but unexpected changes, especially in critical partitions, may indicate a potential security breach.

## Contributions

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

This project is licensed under the MIT license.

```
MIT License

Copyright (c) 2023

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Disclaimer

This tool is provided for educational and security research purposes only. The authors are not responsible for any misuse or damage caused by the use of this tool. Use at your own risk.

## Author

@dcomp7 with assistance from Claude 3.7 Sonnet