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
# Save Naabu output so httpx can actually use the discovered ports
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

# --- Phase 4: Crawling & Static Analysis ---
echo "[*] Phase 4: Deep crawling (Katana)..."
katana -list "$ALIVE_TARGETS" -silent -jc -kf all -d 3 -fs rdn -o "$CRAWLED_URLS"

if [ -s "$CRAWLED_URLS" ]; then
    # Extract ONLY static/source files to avoid downloading entire HTML pages
    echo "[*] Filtering JS, JSON, and Map files..."
    grep -iE '\.(js|json|map|xml|yaml|yml)($|\?)' "$CRAWLED_URLS" | sort -u > "$JS_FILES"

    if [ -s "$JS_FILES" ]; then
        echo "[*] Downloading static code with 10 threads..."
        # Using wget to fetch source. Cut query parameters to save files properly.
        cat "$JS_FILES" | xargs -I % -P 10 bash -c 'wget -q -P "$1" "${2%\?*}" --tries=2 --timeout=10 --no-check-certificate 2>/dev/null' _ "$STATIC_CODE_DIR" %
        
        # --- Trivy Scan ---
        echo "[*] Running Trivy scan..."
        trivy fs "$STATIC_CODE_DIR" --severity HIGH,CRITICAL --format table -o "$TRIVY_OUT" 2>/dev/null
        
        if [ -s "$TRIVY_OUT" ]; then
            echo "--- Trivy Vuln Report ---" | notify -p discord
            cat "$TRIVY_OUT" | notify -p discord -bulk
        fi

        # --- Semgrep Scan ---
        echo "[*] Running Semgrep scan..."
        # Using official Semgrep registries for SAST and Secrets
        semgrep scan --config="p/javascript" --config="p/secrets" \
            --json -o "$SEMGREP_OUT" "$STATIC_CODE_DIR" 2>/dev/null
        
        semgrep scan --config="p/default" --config="p/secrets" \
            --min-severity=ERROR --emacs --quiet "$STATIC_CODE_DIR" > "$SEMGREP_TXT" 2>/dev/null

        if [ -s "$SEMGREP_TXT" ]; then
            echo "--- Semgrep Static Analysis Report ---" | notify -p discord
            head -n 50 "$SEMGREP_TXT" | notify -p discord -bulk 
            echo "...(Check $SEMGREP_OUT for full details)" | notify -p discord
        else
            echo "Semgrep finished: No issues found." | notify -p discord
        fi
    else
        echo "[!] No static source files found during crawl."
    fi
fi

# --- Phase 5: Nuclei Scan ---
echo "[*] Phase 5: Running Nuclei..."
if [ -s "$CRAWLED_URLS" ]; then
    # Pass ALL crawled URLs (not just JS) to nuclei to test for endpoints/vulns
    cat "$CRAWLED_URLS" | nuclei \
        -as \
        -severity medium,high,critical \
        -rl 100 -bs 25 -c 15 \
        -et tags/dos \
        -silent -stream -o "$NUCLEI_RESULT" | notify -p discord -bulk
else
    echo "[!] No URLs discovered for Nuclei scanning."
fi

echo -e "\n[+] Pipeline finished. Results saved in: $OUTPUT_DIR"
