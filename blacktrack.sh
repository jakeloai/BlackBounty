#!/bin/bash

# --- Color Definitions (Keep Banner Red, rest clean) ---
RED='\033[0;31m'
NC='\033[0m'

# --- Banner ---
echo -e "${RED}"
echo "__________.__                 __  ___________                     __   "
echo "\______   \  | _____    ____ |  | \__    ___/___________    ____ |  | __"
echo " |    |  _/  | \__  \ _/ ___\|  |   |    |  \_  __ \__  \ _/ ___\|  |/ /"
echo " |    |   \  |__/ __ \\  \___|  |__ |    |   |  | \// __ \\  \___|    < "
echo " |______  /____(__  / \___  >____/ |____|   |__|  (____  / \___  >__|_ \\"
echo "        \/        \/      \/                            \/      \/     \/"
echo -e "${NC}"

# --- Help Menu ---
show_help() {
    echo "Usage: ./blacktrack.sh [options]"
    echo ""
    echo "Options:"
    echo "  -r <file>    Root Domain file (Directly to httpx, skips Subfinder)"
    echo "  -s <file>    Subdomain file (Runs Subfinder for wildcard discovery)"
    echo "  -h, --help   Show this help message"
    echo ""
    echo "Examples:"
    echo "  1. Root only:      ./blacktrack.sh -r root.txt"
    echo "  2. Subdomain only: ./blacktrack.sh -s subdomains.txt"
    echo "  3. Mixed mode:     ./blacktrack.sh -r root.txt -s subdomains.txt"
    exit 0
}

# --- Argument Parsing ---
ROOT_FILE=""
SUB_FILE=""

while getopts "r:s:h" opt; do
    case $opt in
        r) ROOT_FILE=$OPTARG ;;
        s) SUB_FILE=$OPTARG ;;
        h) show_help ;;
        *) show_help ;;
    esac
done

# --- Validation ---
if [[ -z "$ROOT_FILE" && -z "$SUB_FILE" ]]; then
    echo "[!] Error: You must provide either -r (Root) or -s (Subdomain) file."
    show_help
fi

# Check if files exist
[[ -n "$ROOT_FILE" && ! -f "$ROOT_FILE" ]] && { echo "[!] Error: Root file '$ROOT_FILE' not found."; exit 1; }
[[ -n "$SUB_FILE" && ! -f "$SUB_FILE" ]] && { echo "[!] Error: Subdomain file '$SUB_FILE' not found."; exit 1; }

# --- Initialization ---
DATE=$(date +%Y%m%d_%H%M)
OUTPUT_DIR="recon_$DATE"
mkdir -p "$OUTPUT_DIR"

ALL_TARGETS="$OUTPUT_DIR/all_target.txt"
ALIVE_TARGETS="$OUTPUT_DIR/all_alive_targets.txt"
CRAWLED_URLS="$OUTPUT_DIR/all_crawled_urls.txt"
NUCLEI_RESULT="$OUTPUT_DIR/nuclei_result.txt"
SUBFINDER_OUT="$OUTPUT_DIR/subdomain_result.txt"

# --- Phase 1: Subdomain Enumeration (-s) ---
if [[ -n "$SUB_FILE" ]]; then
    echo "[*] Phase 1: Running Subfinder on $SUB_FILE..."
    subfinder -dL "$SUB_FILE" -silent -o "$SUBFINDER_OUT"
fi

# --- Phase 2: Combine and Sort ---
echo "[*] Phase 2: Merging target lists..."
if [[ -n "$ROOT_FILE" && -n "$SUB_FILE" ]]; then
    cat "$ROOT_FILE" "$SUBFINDER_OUT" | sort -u > "$ALL_TARGETS"
elif [[ -n "$ROOT_FILE" ]]; then
    sort -u "$ROOT_FILE" > "$ALL_TARGETS"
else
    sort -u "$SUBFINDER_OUT" > "$ALL_TARGETS"
fi

# --- Phase 3: Check Alive (httpx-toolkit) ---
echo "[*] Phase 3: Probing alive hosts (httpx-toolkit)..."
httpx-toolkit -l "$ALL_TARGETS" -fc 404 -silent -o "$ALIVE_TARGETS"

if [ ! -s "$ALIVE_TARGETS" ]; then
    echo "[!] Warning: No alive targets found. Exiting."
    exit 0
fi

# --- Phase 4: Crawling (Katana) ---
echo "[*] Phase 4: Deep crawling (Katana)..."
katana -list "$ALIVE_TARGETS" -silent -jc -kf all -d 3 -fs rdn -o "$CRAWLED_URLS"

# --- Phase 5: Vulnerability Scanning (Nuclei) ---
echo "[*] Phase 5: Running Nuclei scan..."
if [ -s "$CRAWLED_URLS" ]; then
    cat "$CRAWLED_URLS" | nuclei \
        -as \
        -severity low,medium,high,critical \
        -rl 100 -bs 25 -c 15 \
        -et tags/dos \
        -silent -stream -o "$NUCLEI_RESULT" | notify -p discord -bulk
else
    echo "[!] No URLs discovered for scanning."
fi

echo -e "\n[+] Pipeline finished. Results saved in: $OUTPUT_DIR"
