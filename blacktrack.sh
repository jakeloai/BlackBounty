#!/bin/bash

# --- Variable Initialization ---
TARGET_FILE=$1
DATE=$(date +%Y%m%d_%H%M)
OUTPUT_DIR="recon_$DATE"
OUTPUT_FILE="$OUTPUT_DIR/nuclei_results.txt"

# --- Error Handling & Environment Check ---

# 1. Input Validation
if [ -z "$TARGET_FILE" ]; then
    echo "[!] Error: No target file specified."
    echo "Usage: ./blacktrack.sh targets.txt"
    exit 1
fi

# 2. Check if file exists
if [ ! -f "$TARGET_FILE" ]; then
    echo "[!] Error: File '$TARGET_FILE' not found."
    exit 1
fi

# 3. Dependency Check
tools=("subfinder" "httpx-toolkit" "katana" "nuclei" "notify")
for tool in "${tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        echo "[!] Error: Dependency '$tool' is not installed."
        exit 1
    fi
done

# Create output directory
mkdir -p "$OUTPUT_DIR" || { echo "[!] Failed to create directory $OUTPUT_DIR"; exit 1; }

echo "[+] Initializing Pipeline: $TARGET_FILE"
echo "[!] Results will be saved in: $OUTPUT_DIR"

# --- Phase 1: Subdomain Discovery ---
# Optimized: Using -dL only for large targets to prevent crashes
echo "[*] Phase 1: Passive Subdomain Enumeration (Subfinder)..."
subfinder -dL "$TARGET_FILE" -silent -o "$OUTPUT_DIR/subs.txt"

if [ ! -s "$OUTPUT_DIR/subs.txt" ]; then
    echo "[!] Warning: No subdomains discovered. Exiting."
    exit 0
fi

# --- Phase 2: Live Host Probing ---
echo "[*] Phase 2: Identifying Alive Hosts (Httpx)..."
cat "$OUTPUT_DIR/subs.txt" | httpx-toolkit -silent -fc 404 -o "$OUTPUT_DIR/alive.txt"

if [ ! -s "$OUTPUT_DIR/alive.txt" ]; then
    echo "[!] Warning: No alive hosts found."
    exit 0
fi

# --- Phase 3: Endpoint Discovery ---
echo "[*] Phase 3: Deep Crawling (Katana)..."
cat "$OUTPUT_DIR/alive.txt" | katana -silent -jc -kf all -d 3 -fs rdn -o "$OUTPUT_DIR/urls.txt"

# --- Phase 4: Vulnerability Scanning ---
echo "[*] Phase 4: Running Nuclei Scan..."
if [ -s "$OUTPUT_DIR/urls.txt" ]; then
    cat "$OUTPUT_DIR/urls.txt" | nuclei \
        -t ~/nuclei-templates \
        -as \
        -itags exploit,cve,lfi,ssrf,sqli,rce,config \
        -severity critical,high \
        -rl 100 -bs 25 -c 15 \
        -et tags/dos \
        -silent -stream -o "$OUTPUT_FILE" | notify -p discord -bulk
else
    echo "[!] No URLs found to scan."
fi

echo "[+] Pipeline Finished. Check $OUTPUT_FILE for findings."
