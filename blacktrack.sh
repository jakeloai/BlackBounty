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
ALIVE_TARGETS="$OUTPUT_DIR/all_alive_targets.txt"
CRAWLED_URLS="$OUTPUT_DIR/all_crawled_urls.txt"
NUCLEI_RESULT="$OUTPUT_DIR/nuclei_result.txt"
SUBFINDER_OUT="$OUTPUT_DIR/subdomain_result.txt"
SEMGREP_OUT="$OUTPUT_DIR/semgrep_results.json"
SEMGREP_TXT="$OUTPUT_DIR/semgrep_summary.txt"
TRIVY_OUT="$OUTPUT_DIR/trivy_results.txt"

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

# Cloud Enumeration
echo "[*] Running Cloud Enum..."
cloud_enum -kf "$ALL_TARGETS" | notify -p discord -bulk

# Port Scanning (Naabu)
echo "[*] Running Naabu Port Scan..."
naabu -list "$ALL_TARGETS" -top-ports 1000 -silent | notify -p discord -bulk

# --- Phase 3: Probing (httpx) ---
echo "[*] Phase 3: Probing alive hosts..."
httpx-toolkit -l "$ALL_TARGETS" -fc 404 -silent -o "$ALIVE_TARGETS"

if [ ! -s "$ALIVE_TARGETS" ]; then
    echo "[!] No alive targets found. Exiting."
    exit 0
fi

# --- Phase 4: Crawling & Static Analysis ---
echo "[*] Phase 4: Deep crawling (Katana)..."
katana -list "$ALIVE_TARGETS" -silent -jc -kf all -d 3 -fs rdn -o "$CRAWLED_URLS"

# 下載所有前端源碼 (暴力併發模式)
if [ -s "$CRAWLED_URLS" ]; then
    echo "[*] Downloading ALL frontend static code with 10 threads..."
    cat "$CRAWLED_URLS" | xargs -I % -P 10 wget -q -P "$STATIC_CODE_DIR" % --tries=2 --timeout=10 --no-check-certificate 2>/dev/null

    # --- Trivy 掃描 (尋找 CVE 與已知漏洞) ---
    echo "[*] Running Trivy scan..."
    # 使用 fs 模式掃描下載的資料夾
    trivy fs "$STATIC_CODE_DIR" --severity HIGH,CRITICAL --format table -o "$TRIVY_OUT"
    
    if [ -s "$TRIVY_OUT" ]; then
        echo "--- Trivy Vuln Report ---" | notify -p discord
        cat "$TRIVY_OUT" | notify -p discord -bulk
    fi

    # --- Semgrep 掃描 (SAST 靜態代碼分析 & Secrets) ---
    echo "[*] Running Semgrep scan..."
    # 同時輸出 JSON (留存資料) 與 純文字摘要 (發送通知)
    semgrep scan --config ~/semgrep-rules/javascript/ --config ~/semgrep-rules/generic/secrets/ \
        --json -o "$SEMGREP_OUT" "$STATIC_CODE_DIR"
    
    # 生成易讀的文字摘要發送給自己
    semgrep scan --config="p/default" --config="p/secrets" \
        --min-severity=ERROR --emacs --quiet "$STATIC_CODE_DIR" > "$SEMGREP_TXT"

    if [ -s "$SEMGREP_TXT" ]; then
        echo "--- Semgrep Static Analysis Report ---" | notify -p discord
        cat "$SEMGREP_TXT" | head -n 50 | notify -p discord -bulk 
        echo "...(Summary truncated if too long, check $SEMGREP_OUT for full details)" | notify -p discord
    else
        echo "Semgrep finished: No issues found." | notify -p discord
    fi
fi

# --- Phase 5: Nuclei Scan ---
echo "[*] Phase 5: Running Nuclei..."
if [ -s "$CRAWLED_URLS" ]; then
    cat "$CRAWLED_URLS" | nuclei \
        -as \
        -severity low,medium,high,critical \
        -rl 100 -bs 25 -c 15 \
        -et tags/dos \
        -silent -stream -o "$NUCLEI_RESULT" | notify -p discord -bulk
else
    echo "[!] No URLs discovered for Nuclei scanning."
fi

echo -e "\n[+] Pipeline finished. Results saved in: $OUTPUT_DIR"
