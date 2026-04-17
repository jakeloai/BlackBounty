#!/bin/bash

# --- Help Menu ---
show_help() {
    echo "Usage: ./blacktrack.sh [options]"
    echo ""
    echo "Options:"
    echo "  -r <file>    Root Domain file (Directly to httpx, skips Subfinder)"
    echo "  -s <file>    Subdomain file (Runs Subfinder for wildcard discovery)"
    echo "  -h, --help    Show this help message"
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

# --- Initialization ---
DATE=$(date +%Y%m%d_%H%M)
OUTPUT_DIR="recon_$DATE"
mkdir -p "$OUTPUT_DIR"

ALL_TARGETS="$OUTPUT_DIR/all_target.txt"
NAABU_PORTS="$OUTPUT_DIR/naabu_ports.txt"
ALIVE_TARGETS="$OUTPUT_DIR/all_alive_targets.txt"
CRAWLED_URLS="$OUTPUT_DIR/all_crawled_urls.txt"
NUCLEI_RESULT="$OUTPUT_DIR/nuclei_result.txt"
SUBFINDER_OUT="$OUTPUT_DIR/subdomain_result.txt"

# --- Phase 1: Subdomain Enumeration ---
if [[ -n "$SUB_FILE" ]]; then
    echo "[*] Phase 1: Running Subfinder..."
    subfinder -dL "$SUB_FILE" -silent -o "$SUBFINDER_OUT"
fi

# --- Phase 2: Merge & Recon Tools ---
echo "[*] Phase 2: Merging target lists..."
if [[ -n "$ROOT_FILE" && -n "$SUB_FILE" ]]; then
    cat "$ROOT_FILE" "$SUBFINDER_OUT" | sort -u > "$ALL_TARGETS"
elif [[ -n "$ROOT_FILE" ]]; then
    sort -u "$ROOT_FILE" > "$ALL_TARGETS"
else
    sort -u "$SUBFINDER_OUT" > "$ALL_TARGETS"
fi

# Port Scanning (Naabu)
echo "[*] Running Naabu Port Scan..."
naabu -list "$ALL_TARGETS" -top-ports 1000 -silent -o "$NAABU_PORTS" | notify -p discord -bulk

# Combine original targets and discovered ports for probing
cat "$ALL_TARGETS" "$NAABU_PORTS" 2>/dev/null | sort -u > "$OUTPUT_DIR/combined_for_httpx.txt"

# --- Phase 3: Probing (httpx) ---
echo "[*] Phase 3: Probing alive hosts..."
httpx-toolkit -l "$OUTPUT_DIR/combined_for_httpx.txt" -fc 404,400 -silent -o "$ALIVE_TARGETS"

if [ ! -s "$ALIVE_TARGETS" ]; then
    echo "[!] No alive targets found. Exiting."
    exit 0
fi

# --- Phase 4: Crawling (Katana) ---
echo "[*] Phase 4: Deep crawling with Katana..."
# 只進行爬蟲獲取 URL，不進行文件下載
katana -list "$ALIVE_TARGETS" -silent -jc -kf all -d 3 -fs rdn -o "$CRAWLED_URLS"

# --- Phase 5: Nuclei Scan ---
echo "[*] Phase 5: Running Nuclei..."
# 同時針對活著的目標 (Alive) 和 爬到的 URL (Crawled) 進行掃描
if [ -s "$CRAWLED_URLS" ]; then
    echo "[*] Scanning crawled URLs with Nuclei..."
    cat "$CRAWLED_URLS" | nuclei \
        -as \
        -severity medium,high,critical \
        -rl 100 -bs 25 -c 15 \
        -et tags/dos \
        -silent -stream -o "$NUCLEI_RESULT" | notify -p discord -bulk
else
    echo "[!] Katana found no URLs, scanning alive targets directly..."
    cat "$ALIVE_TARGETS" | nuclei -as -severity medium,high,critical -silent -o "$NUCLEI_RESULT" | notify -p discord
fi

echo -e "\n[+] Pipeline finished. Results saved in: $OUTPUT_DIR"
