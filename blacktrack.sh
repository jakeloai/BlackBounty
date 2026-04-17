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
STATIC_CODE_DIR="$OUTPUT_DIR/frontend_static_code"
mkdir -p "$OUTPUT_DIR" "$STATIC_CODE_DIR"

ALL_TARGETS="$OUTPUT_DIR/all_target.txt"
NAABU_PORTS="$OUTPUT_DIR/naabu_ports.txt"
ALIVE_TARGETS="$OUTPUT_DIR/all_alive_targets.txt"
CRAWLED_URLS="$OUTPUT_DIR/all_crawled_urls.txt"
JS_FILES="$OUTPUT_DIR/js_static_files.txt"
NUCLEI_RESULT="$OUTPUT_DIR/nuclei_result.txt"
SUBFINDER_OUT="$OUTPUT_DIR/subdomain_result.txt"
SEMGREP_OUT="$OUTPUT_DIR/semgrep_results.json"
SEMGREP_TXT="$OUTPUT_DIR/semgrep_summary.txt"
TRIVY_OUT="$OUTPUT_DIR/trivy_results.txt"
CLOUD_KEYWORDS="$OUTPUT_DIR/cloud_keywords.txt"

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

# --- Phase 5: Nuclei Scan ---
echo "[*] Phase 5: Running Nuclei..."
if [ -s "$ALIVE_TARGETS" ]; then
    cat "$ALIVE_TARGETS" | nuclei \
        -as \
        -severity medium,high,critical \
        -rl 100 -bs 25 -c 15 \
        -et tags/dos \
        -silent -stream -o "$NUCLEI_RESULT" | notify -p discord -bulk
else
    echo "[!] No targets discovered for Nuclei scanning."
fi

echo -e "\n[+] Pipeline finished. Results saved in: $OUTPUT_DIR"
