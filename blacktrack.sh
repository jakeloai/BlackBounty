#!/bin/bash

# --- Help Menu ---
show_help() {
    echo "Usage: ./blacktrack.sh [target_file] [options]"
    echo ""
    echo "Options:"
    echo "  -r, --include-root    Automatically merge root domains from target file after discovery"
    echo "  -h, --help            Show this help message and exit"
    echo ""
    echo "Example:"
    echo "  ./blacktrack.sh targets.txt --include-root"
    exit 0
}

# --- Argument Parsing ---
INCLUDE_ROOT=false
TARGET_FILE=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -r|--include-root) INCLUDE_ROOT=true; shift ;;
        -h|--help) show_help ;;
        *) TARGET_FILE=$1; shift ;;
    esac
done

# --- Variable Initialization ---
DATE=$(date +%Y%m%d_%H%M)
OUTPUT_DIR="recon_$DATE"
OUTPUT_FILE="$OUTPUT_DIR/nuclei_results.txt"

# --- Error Handling & Environment Check ---

if [ -z "$TARGET_FILE" ]; then
    echo "[!] Error: No target file specified."
    show_help
fi

if [ ! -f "$TARGET_FILE" ]; then
    echo "[!] Error: File '$TARGET_FILE' not found."
    exit 1
fi

tools=("subfinder" "httpx-toolkit" "katana" "nuclei" "notify")
for tool in "${tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        echo "[!] Error: Dependency '$tool' is not installed."
        exit 1
    fi
done

mkdir -p "$OUTPUT_DIR" || { echo "[!] Failed to create directory $OUTPUT_DIR"; exit 1; }

echo "[+] Initializing Pipeline: $TARGET_FILE"
echo "[!] Include Root Domain: $INCLUDE_ROOT"
echo "[!] Results will be saved in: $OUTPUT_DIR"

# --- Phase 1: Subdomain Discovery ---
echo "[*] Phase 1: Passive Subdomain Enumeration (Subfinder)..."
subfinder -dL "$TARGET_FILE" -silent -o "$OUTPUT_DIR/subs_found.txt"

# --- Logic: Automated Merging ---
if [ "$INCLUDE_ROOT" = true ]; then
    echo "[*] Mode: Merging root domains with discovered subdomains..."
    cat "$TARGET_FILE" "$OUTPUT_DIR/subs_found.txt" | sort -u > "$OUTPUT_DIR/all_targets.txt"
else
    echo "[*] Mode: Using only discovered subdomains..."
    cp "$OUTPUT_DIR/subs_found.txt" "$OUTPUT_DIR/all_targets.txt"
fi

if [ ! -s "$OUTPUT_DIR/all_targets.txt" ]; then
    echo "[!] Warning: No targets found after Phase 1. Exiting."
    exit 0
fi

# --- Phase 2: Live Host Probing ---
echo "[*] Phase 2: Identifying Alive Hosts (Httpx)..."
cat "$OUTPUT_DIR/all_targets.txt" | httpx-toolkit -silent -fc 404 -o "$OUTPUT_DIR/alive.txt"

if [ ! -s "$OUTPUT_DIR/alive.txt" ]; then
    echo "[!] Warning: No alive hosts found."
    exit 0
fi

# --- Phase 3: Endpoint Discovery ---
echo "[*] Phase 3: Deep Crawling (Katana)..."
cat "$OUTPUT_DIR/alive.txt" | katana -silent -jc -kf all -d 3 -fs rdn -o "$OUTPUT_DIR/urls.txt"

# --- Phase 4: Vulnerability Scanning ---
echo "[*] Phase 4: Running Nuclei Scan (Low to Critical)..."
if [ -s "$OUTPUT_DIR/urls.txt" ]; then
    cat "$OUTPUT_DIR/urls.txt" | nuclei \
        -t ~/nuclei-templates \
        -as \
        -severity low,medium,high,critical \
        -rl 100 -bs 25 -c 15 \
        -et tags/dos \
        -silent -stream -o "$OUTPUT_FILE" | notify -p discord -bulk
else
    echo "[!] No URLs found to scan."
fi

echo "[+] Pipeline Finished. Check $OUTPUT_FILE for findings."
