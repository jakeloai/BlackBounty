#!/bin/bash
# blacktrack.sh - v6.5 Master Edition (Enhanced Stability / Direct Mode)

show_help() {
    echo "Usage: ./blacktrack.sh [options]"
    echo "Options:"
    echo "  -r <file>    Root Domain file (Strict Scope)"
    echo "  -s <file>    Subdomain targets (Enables Passive Discovery)"
    echo "  -a <file>    Amass deep brute targets"
    echo "  -w <file>    Wordlist for Amass"
    echo "  -h            Show help"
    exit 0
}

# --- Default Config ---
WORDLIST="/usr/share/wordlists/amass/subdomains-top1mil.txt"
AMASS_FILE=""; ROOT_FILE=""; SUB_FILE=""

while getopts "r:s:a:w:h" opt; do
    case $opt in
        r) ROOT_FILE=$OPTARG ;;
        s) SUB_FILE=$OPTARG ;;
        a) AMASS_FILE=$OPTARG ;;
        w) WORDLIST=$OPTARG ;;
        h) show_help ;;
        *) show_help ;;
    esac
done

if [[ -z "$ROOT_FILE" && -z "$SUB_FILE" && -z "$AMASS_FILE" ]]; then show_help; fi

# --- Environment Setup ---
DATE=$(date +%Y%m%d_%H%M)
OUTPUT_DIR="scan_$DATE"
REPORT_FILE="$OUTPUT_DIR/BlackTrack_Report.md"
mkdir -p "$OUTPUT_DIR/assets" "$OUTPUT_DIR/logs"

echo "[*] Initializing BlackTrack v6.5 (Smart Scoping)..."

# --- Phase 1: Recon & Shadow Discovery ---
if [[ -n "$SUB_FILE" ]]; then
    echo "[*] Phase 1: Subdomain Enumeration Enabled (-s detected)..."
    
    # 1a. Passive Discovery via Subfinder
    subfinder -dL "$SUB_FILE" -all -silent -o "$OUTPUT_DIR/assets/passive_subs.txt"

    # 1b. Deep Brute Force via Amass
    if [[ -n "$AMASS_FILE" ]]; then
        echo "[*] Running Amass Deep Brute Force..."
        amass enum -brute -d "$AMASS_FILE" -w "$WORDLIST" -o "$OUTPUT_DIR/assets/amass_subs.txt"
    fi

    # 1c. Discovery via TLSX (Safely handle potentially missing files)
    touch "$OUTPUT_DIR/assets/passive_subs.txt" "$OUTPUT_DIR/assets/amass_subs.txt"
    [[ -n "$ROOT_FILE" ]] && cat "$ROOT_FILE" > "$OUTPUT_DIR/assets/tmp_all.txt"
    cat "$OUTPUT_DIR/assets/passive_subs.txt" "$OUTPUT_DIR/assets/amass_subs.txt" >> "$OUTPUT_DIR/assets/tmp_all.txt"
    
    tlsx -l "$OUTPUT_DIR/assets/tmp_all.txt" -san -ro -silent -o "$OUTPUT_DIR/assets/shadow_assets.txt"

    # Consolidate all domains
    cat "$OUTPUT_DIR/assets/tmp_all.txt" "$OUTPUT_DIR/assets/shadow_assets.txt" 2>/dev/null | sort -u > "$OUTPUT_DIR/assets/total_domains.txt"
    rm "$OUTPUT_DIR/assets/tmp_all.txt"
else
    echo "[*] Phase 1: Strict Scope Mode (-r only). Skipping enumeration..."
    sort -u "$ROOT_FILE" > "$OUTPUT_DIR/assets/total_domains.txt"
fi

# --- Phase 2: Web Recon & Optimized Crawling ---
echo "[*] Phase 2: Probing and Optimized Crawling..."
httpx-toolkit -l "$OUTPUT_DIR/assets/total_domains.txt" -silent -o "$OUTPUT_DIR/assets/alive.txt"

if [[ -s "$OUTPUT_DIR/assets/alive.txt" ]]; then
    echo "[*] Starting Katana Crawling..."
    # Run Katana to raw file first to prevent pipeline breakage
    katana -list "$OUTPUT_DIR/assets/alive.txt" -jc -kf all -d 3 -fs rdn -silent -con 30 -o "$OUTPUT_DIR/assets/urls_raw.txt"

    # Apply noise filter
    if [[ -s "$OUTPUT_DIR/assets/urls_raw.txt" ]]; then
        grep -avE "\.(jpg|jpeg|gif|png|ico|css|svg|woff|woff2|ttf|otf|eot|mp3|mp4|avi|flv|wmv|pdf|zip|gz|rar)$" \
        "$OUTPUT_DIR/assets/urls_raw.txt" | sort -u > "$OUTPUT_DIR/assets/urls_filtered.txt"
    fi

    # Fallback: If Katana finds nothing or filter kills everything, use alive.txt
    if [[ ! -s "$OUTPUT_DIR/assets/urls_filtered.txt" ]]; then
        echo "[!] Katana output empty or filtered. Falling back to alive.txt for Nuclei..."
        cp "$OUTPUT_DIR/assets/alive.txt" "$OUTPUT_DIR/assets/urls_filtered.txt"
    fi
else
    echo "[!] No alive assets found. Skipping Phase 2 & 3."
    exit 1
fi

# --- Phase 3: Nuclear Nuclei Scan ---
TARGET_COUNT=$(wc -l < "$OUTPUT_DIR/assets/urls_filtered.txt")
echo "[*] Phase 3: Launching Direct Nuclear Nuclei Attack on $TARGET_COUNT targets..."
nuclei -l "$OUTPUT_DIR/assets/urls_filtered.txt" \
  -t ~/nuclei-templates/ \
  -tlsi \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36" \
  -rl 50 -c 15 -timeout 6 -retries 2 -mhe 10 \
  -severity low,medium,high,critical \
  -stats -si 15 \
  -o "$OUTPUT_DIR/nuclear_results.txt" | notify -p discord -bulk -silent

# --- Phase 4: BBOT Final Sweep ---
echo "[*] Phase 4: BBOT OSINT and Kitchen-Sink..."
bbot -t "$OUTPUT_DIR/assets/alive.txt" -p kitchen-sink --allow-deadly --force -o "$OUTPUT_DIR/bbot_results" > /dev/null 2>&1

# --- Phase 5: Automated Report Generation ---
echo "[*] Phase 5: Generating Markdown Report..."
{
    echo "# BlackTrack v6.5 Scan Report"
    echo "Scan Date: $(date)"
    echo "Mode: $( [[ -n "$SUB_FILE" ]] && echo "Full Enumeration" || echo "Strict Scope" )"
    echo "---"
    echo "## 1. Recon Summary"
    echo "* Total Unique Domains: $(cat "$OUTPUT_DIR/assets/total_domains.txt" 2>/dev/null | wc -l)"
    echo "* Alive Web Assets: $(cat "$OUTPUT_DIR/assets/alive.txt" 2>/dev/null | wc -l)"
    if [[ -n "$SUB_FILE" ]]; then
        echo "* Shadow Assets (TLSX): $(cat "$OUTPUT_DIR/assets/shadow_assets.txt" 2>/dev/null | wc -l)"
    fi
    echo ""
    echo "## 2. Critical/High Findings (Nuclei)"
    echo "| Severity | Template | Target | Match |"
    echo "| :--- | :--- | :--- | :--- |"
    if [[ -f "$OUTPUT_DIR/nuclear_results.txt" ]]; then
        grep -E "critical|high" "$OUTPUT_DIR/nuclear_results.txt" | awk '{print "| " $3 " | " $2 " | " $4 " | " $6 " |"}'
    fi
    echo ""
} > "$REPORT_FILE"

echo "[+] Scan Complete. Report: $REPORT_FILE"
CRIT_COUNT=$(grep -cE 'critical|high' "$OUTPUT_DIR/nuclear_results.txt" 2>/dev/null || echo 0)
echo "BlackTrack Direct Scan Finished. Critical Found: $CRIT_COUNT" | notify -p discord -silent
