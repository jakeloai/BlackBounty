#!/bin/bash

# --- Help Menu ---
show_help() {
    echo "Usage: ./blacktrack.sh [options]"
    echo ""
    echo "Options:"
    echo "  -r <file>    Root Domain file (Directly to httpx, skips Subfinder)"
    echo "  -s <file>    Subdomain file (Runs Subfinder for wildcard discovery)"
    echo "  -h, --help   Show this help message"
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

if [[ -z "$ROOT_FILE" && -z "$SUB_FILE" ]]; then
    echo "[!] Error: You must provide either -r or -s file."
    show_help
fi

# --- Initialization ---
DATE=$(date +%Y%m%d_%H%M)
OUTPUT_DIR="recon_$DATE"
mkdir -p "$OUTPUT_DIR"

ALL_TARGETS="$OUTPUT_DIR/all_target.txt"
NAABU_PORTS="$OUTPUT_DIR/naabu_ports.txt"
ALIVE_TARGETS="$OUTPUT_DIR/all_alive_targets.txt"
FEROX_OUT="$OUTPUT_DIR/ferox_results.txt"
CLEAN_FEROX="$OUTPUT_DIR/clean_ferox.txt"
CRAWLED_URLS="$OUTPUT_DIR/all_crawled_urls.txt"
FINAL_URLS="$OUTPUT_DIR/final_urls_combined.txt"
FINAL_SHUFFLED="$OUTPUT_DIR/alive_urls_shuffled.txt"
NUCLEI_RESULT="$OUTPUT_DIR/nuclei_result.txt"
SUBFINDER_OUT="$OUTPUT_DIR/subdomain_result.txt"

# --- Phase 1: Subdomain Enumeration ---
if [[ -n "$SUB_FILE" ]]; then
    echo "[*] Phase 1: Running Subfinder..."
    subfinder -dL "$SUB_FILE" -silent -o "$SUBFINDER_OUT"
fi

# --- Phase 2: Merge & Port Scanning ---
echo "[*] Phase 2: Merging & Port Scanning..."
if [[ -n "$ROOT_FILE" && -n "$SUB_FILE" ]]; then
    cat "$ROOT_FILE" "$SUBFINDER_OUT" | sort -u > "$ALL_TARGETS"
elif [[ -n "$ROOT_FILE" ]]; then
    sort -u "$ROOT_FILE" > "$ALL_TARGETS"
else
    sort -u "$SUBFINDER_OUT" > "$ALL_TARGETS"
fi

naabu -list "$ALL_TARGETS" -top-ports 1000 -silent -o "$NAABU_PORTS" | notify -p discord -bulk
cat "$ALL_TARGETS" "$NAABU_PORTS" 2>/dev/null | sort -u > "$OUTPUT_DIR/combined_for_httpx.txt"

# --- Phase 3: Probing (httpx) ---
echo "[*] Phase 3: Probing alive hosts..."
httpx-toolkit -l "$OUTPUT_DIR/combined_for_httpx.txt" -fc 404,400 -silent -o "$ALIVE_TARGETS"

if [ ! -s "$ALIVE_TARGETS" ]; then
    echo "[!] No alive targets found. Exiting."
    exit 0
fi

# --- Phase 4: Directory Fuzzing (Feroxbuster) ---
echo "[*] Phase 4: Fuzzing directories with Feroxbuster..."
cat "$ALIVE_TARGETS" | feroxbuster --stdin --smart --unique --no-recursion --random-agent -s 200 --silent \
    -x php,aspx,jsp,env,bak,zip,git,config -o "$FEROX_OUT"

grep -aoE "https?://[a-zA-Z0-9\./\?&%\=\-\_:]+" "$FEROX_OUT" | sort -u > "$CLEAN_FEROX"

# --- Phase 5: Crawling (Katana) ---
echo "[*] Phase 5: Deep crawling with Katana..."
katana -list "$ALIVE_TARGETS" -silent -jc -kf all -d 3 -fs rdn -o "$CRAWLED_URLS"

# --- Phase 6: Data Consolidation & Stealth Prep ---
echo "[*] Phase 6: Merging all discovered URLs & Shuffling..."

cat "$ALIVE_TARGETS" "$CRAWLED_URLS" "$CLEAN_FEROX" | sort -u > "$FINAL_URLS"

shuf "$FINAL_URLS" > "$FINAL_SHUFFLED"

# --- Phase 7: Vulnerability Scanning (Nuclei) ---
echo "[*] Phase 7: Running Nuclei on all discovered endpoints..."
cat "$FINAL_SHUFFLED" | nuclei \
    -as \
    -severity medium,high,critical \
    -rl 100 -bs 25 -c 15 \
    -et tags/dos \
    -silent -stream -o "$NUCLEI_RESULT" | notify -p discord -bulk

# --- Phase 8: Full Recon (BBOT) ---
echo "[*] Phase 8: Running BBOT Kitchen Sink (Heavy Scanning)..."

bbot -t "$FINAL_SHUFFLED" -p kitchen-sink --allow-deadly --force | notify -p discord -bulk

echo -e "\n[+] Full Pipeline Finished. Results saved in: $OUTPUT_DIR"
