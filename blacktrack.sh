#!/bin/bash

# --- Help Menu ---
show_help() {
    echo "Usage: ./blacktrack.sh [options]"
    echo "Options:"
    echo "  -r <file>    Root Domain file (Single assets)"
    echo "  -s <file>    Subdomain targets (Passive discovery)"
    echo "  -a <file>    Amass deep brute targets (Recursive mapping)"
    echo "  -w <file>    Wordlist for Amass"
    echo "  -h           Show help"
    exit 0
}

# --- Argument Parsing ---
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

# --- Initialization ---
DATE=$(date +%Y%m%d_%H%M)
OUTPUT_DIR="nuclear_web_$DATE"
mkdir -p "$OUTPUT_DIR/secrets" "$OUTPUT_DIR/amass_raw" "$OUTPUT_DIR/permutations"
PROCESSED_LOG="$OUTPUT_DIR/processed.log"

# --- Phase 1: Passive Surface Mapping ---
echo "[*] Phase 1: Passive Subdomain Mapping..." | notify -p discord
if [[ -n "$SUB_FILE" ]]; then
    subfinder -dL "$SUB_FILE" -silent -o "$OUTPUT_DIR/passive_subs.txt"
fi

# --- Phase 2: Recursive Amass Brute Force ---
if [[ -n "$AMASS_FILE" ]]; then
    echo "[*] Phase 2: Starting Recursive Amass Brute Force..." | notify -p discord
    sort -u "$AMASS_FILE" | while read -r domain; do
        [ -z "$domain" ] && continue
        if grep -q "^$domain$" "$PROCESSED_LOG" 2>/dev/null; then continue; fi

        echo "[>] Deep Diving into: $domain"
        amass enum -d "$domain" -brute -w "$WORDLIST" -recursive -oA "$OUTPUT_DIR/amass_raw/${domain}_deep"
        echo "$domain" >> "$PROCESSED_LOG"
    done
    cat "$OUTPUT_DIR/amass_raw/"*.txt | sort -u > "$OUTPUT_DIR/amass_subs.txt"
fi

# --- Phase 3: Permutation & Web Probing ---
echo "[*] Phase 3: Web Discovery & Permutation..." | notify -p discord
cat "$ROOT_FILE" "$OUTPUT_DIR/passive_subs.txt" "$OUTPUT_DIR/amass_subs.txt" 2>/dev/null | sort -u > "$OUTPUT_DIR/base_assets.txt"

if command -v dnsgen &> /dev/null; then
    cat "$OUTPUT_DIR/base_assets.txt" | dnsgen - | httpx-toolkit -p 80,443,8080,8443 -silent -o "$OUTPUT_DIR/permutations/alive_web_perms.txt"
fi

cat "$OUTPUT_DIR/base_assets.txt" "$OUTPUT_DIR/permutations/alive_web_perms.txt" 2>/dev/null | sort -u > "$OUTPUT_DIR/all_web_assets.txt"
httpx-toolkit -l "$OUTPUT_DIR/all_web_assets.txt" -title -server -status-code -silent -o "$OUTPUT_DIR/alive_details.txt"
cat "$OUTPUT_DIR/alive_details.txt" | awk '{print $1}' > "$OUTPUT_DIR/alive.txt"

# --- Phase 4: Extreme Deep Crawling (Katana Depth 5) ---
echo "[*] Phase 4: Katana Deep Crawling for Params & Secrets..." | notify -p discord
katana -list "$OUTPUT_DIR/alive.txt" -jc -kf all -d 5 -fs rdn -o "$OUTPUT_DIR/urls.txt"

grep ".js" "$OUTPUT_DIR/urls.txt" | sort -u > "$OUTPUT_DIR/js_urls.txt"
if [ -s "$OUTPUT_DIR/js_urls.txt" ]; then
    trufflehog pipeline --file="$OUTPUT_DIR/js_urls.txt" --only-verified > "$OUTPUT_DIR/secrets/js_secrets.txt"
fi

# --- Phase 5: The "Nuclear" Nuclei Sweep (The All-In Attack) ---
echo "[*] Phase 5: Executing Nuclear Nuclei Scan (6700+ Templates)..." | notify -p discord
# 呢度係你要求嘅全量模式：無 Tag, 無 AS, 全力轟炸
nuclei -l "$OUTPUT_DIR/urls.txt" \
  -t ~/nuclei-templates/ \
  -tlsi \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36" \
  -rl 10 \
  -c 5 \
  -timeout 20 \
  -retries 2 \
  -severity low,medium,high,critical \
  -interactsh-server oast.pro \
  -stats -si 15 \
  -o "$OUTPUT_DIR/nuclear_nuclei_results.txt" | notify -p discord -bulk

# --- Phase 6: Final Heavyweight BBOT ---
echo "[*] Phase 6: BBOT Kitchen-Sink Mode..." | notify -p discord
bbot -t "$OUTPUT_DIR/all_web_assets.txt" -p kitchen-sink --allow-deadly --force | notify -p discord -bulk

echo "[+] BlackTrack v5.0 Finished. Check $OUTPUT_DIR/nuclear_nuclei_results.txt for the gold." | notify -p discord
