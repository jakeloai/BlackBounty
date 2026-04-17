#!/bin/bash
# blacktrack.sh - v6.5 Master Edition (Full Recon / Direct Mode)

show_help() {
    echo "Usage: ./blacktrack.sh [options]"
    echo "Options:"
    echo "  -r <file>    Root Domain file"
    echo "  -s <file>    Subdomain targets (Passive)"
    echo "  -a <file>    Amass deep brute targets"
    echo "  -w <file>    Wordlist for Amass"
    echo "  -h           Show help"
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

echo "[*] Initializing BlackTrack v6.5 (Direct Mode)..."

# --- Phase 1: Recon & Shadow Discovery ---
echo "[*] Phase 1: Mapping Surface and Shadow Assets..."

# 1a. Passive Discovery via Subfinder
if [[ -n "$SUB_FILE" ]]; then
    subfinder -dL "$SUB_FILE" -all -silent -o "$OUTPUT_DIR/assets/passive_subs.txt"
fi

# 1b. Deep Brute Force via Amass
if [[ -n "$AMASS_FILE" ]]; then
    echo "[*] Running Amass Deep Brute Force..."
    amass enum -brute -d "$AMASS_FILE" -w "$WORDLIST" -o "$OUTPUT_DIR/assets/amass_subs.txt"
fi

# 1c. Discovery via TLSX (SAN/Cert Transparency)
# Combine current findings to feed TLSX
cat "$ROOT_FILE" "$OUTPUT_DIR/assets/passive_subs.txt" "$OUTPUT_DIR/assets/amass_subs.txt" 2>/dev/null | \
tlsx -san -ro -silent -o "$OUTPUT_DIR/assets/shadow_assets.txt"

# Final Domain Consolidation
cat "$ROOT_FILE" "$OUTPUT_DIR/assets/passive_subs.txt" "$OUTPUT_DIR/assets/amass_subs.txt" "$OUTPUT_DIR/assets/shadow_assets.txt" 2>/dev/null | sort -u > "$OUTPUT_DIR/assets/total_domains.txt"

# --- Phase 2: Web Recon & Optimized Crawling ---
echo "[*] Phase 2: Probing and Optimized Crawling..."
httpx-toolkit -l "$OUTPUT_DIR/assets/total_domains.txt" -silent -o "$OUTPUT_DIR/assets/alive.txt"

# Katana Crawling (Increased concurrency for Direct Mode)
katana -list "$OUTPUT_DIR/assets/alive.txt" -jc -kf all -d 3 -fs rdn -silent -con 30 | \
grep -avE "\.(jpg|jpeg|gif|png|ico|css|svg|woff|woff2|ttf|otf|eot|mp3|mp4|avi|flv|wmv|pdf|zip|gz|rar)$" \
> "$OUTPUT_DIR/assets/urls_filtered.txt"

# --- Phase 3: Nuclear Nuclei Scan (Direct Mode) ---
echo "[*] Phase 3: Launching Direct Nuclear Nuclei Attack..."
# Removed all proxy flags. Adjusted rl/c for direct high-speed scanning.
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
    echo "# BlackTrack v6.5 Scan Report (Direct Mode)"
    echo "Scan Date: $(date)"
    echo "Target: $ROOT_FILE"
    echo "---"
    echo "## 1. Recon Summary"
    echo "* Total Unique Domains: $(cat "$OUTPUT_DIR/assets/total_domains.txt" 2>/dev/null | wc -l)"
    echo "* Alive Web Assets: $(cat "$OUTPUT_DIR/assets/alive.txt" 2>/dev/null | wc -l)"
    echo "* Shadow Assets (TLSX): $(cat "$OUTPUT_DIR/assets/shadow_assets.txt" 2>/dev/null | wc -l)"
    if [[ -f "$OUTPUT_DIR/assets/amass_subs.txt" ]]; then
        echo "* Amass Bruteforce Assets: $(cat "$OUTPUT_DIR/assets/amass_subs.txt" 2>/dev/null | wc -l)"
    fi
    echo ""
    echo "## 2. Critical/High Findings (Nuclei)"
    echo "| Severity | Template | Target | Match |"
    echo "| :--- | :--- | :--- | :--- |"
    grep -E "critical|high" "$OUTPUT_DIR/nuclear_results.txt" | awk '{print "| " $3 " | " $2 " | " $4 " | " $6 " |"}'
    echo ""
    echo "## 3. Top Attack Surfaces (Manual Review Required)"
    echo "\`\`\`text"
    grep "?" "$OUTPUT_DIR/assets/urls_filtered.txt" | head -n 20
    echo "\`\`\`"
    echo ""
    echo "## 4. Next Steps"
    echo "1. Verify Nuclei Critical/High findings manually."
    echo "2. Check filtered URLs for IDOR, SQLi, and SSRF."
    echo "3. Review shadow_assets.txt for dev/staging environments."
} > "$REPORT_FILE"

echo "[+] Scan Complete. Report: $REPORT_FILE"
echo "BlackTrack Direct Scan Finished. Critical Found: $(grep -cE 'critical|high' "$OUTPUT_DIR/nuclear_results.txt")" | notify -p discord -silent
