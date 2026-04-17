#!/bin/bash

# --- Help Menu ---
show_help() {
    echo "Usage: ./blacktrack.sh [options]"
    echo "Options:"
    echo "  -r <file>    Root Domain file (Directly to httpx)"
    echo "  -s <file>    Subdomain file (For Subfinder discovery)"
    echo "  -a <file>    Amass target file (Specific domains for deep brute force)"
    echo "  -w <file>    Wordlist for Amass brute forcing (Default: top 1mil)"
    echo "  -h           Show help"
    exit 0
}

# --- Argument Parsing ---
WORDLIST="/usr/share/wordlists/amass/subdomains-top1mil.txt"
AMASS_FILE=""
ROOT_FILE=""
SUB_FILE=""

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
OUTPUT_DIR="money_recon_$DATE"
mkdir -p "$OUTPUT_DIR/secrets" "$OUTPUT_DIR/amass_raw"

# --- Phase 0: Targeted Amass Enumeration ---
if [[ -n "$AMASS_FILE" ]]; then
    echo "[*] Phase 0: Starting Targeted Amass Brute Force..." | notify -p discord
    while read -r domain; do
        [ -z "$domain" ] && continue
        echo "[>] Deep Scanning: $domain"
        # 使用你指定的檔案行強力 brute force
        amass enum -d "$domain" -brute -w "$WORDLIST" -oA "$OUTPUT_DIR/amass_raw/${domain}_full"
    done < "$AMASS_FILE"
    
    cat "$OUTPUT_DIR/amass_raw/"*.txt | sort -u > "$OUTPUT_DIR/amass_subs.txt"
    echo "[+] Amass finished. Found $(wc -l < "$OUTPUT_DIR/amass_subs.txt") subdomains." | notify -p discord
fi

# --- Phase 1: Subfinder & Cloud Discovery ---
if [[ -n "$SUB_FILE" ]]; then
    echo "[*] Phase 1: Fast Subdomain Discovery & Cloud Enum..."
    subfinder -dL "$SUB_FILE" -silent -o "$OUTPUT_DIR/subfinder_subs.txt"
    
    # Cloud Storage Leakage (以第一個 domain 做關鍵字)
    FIRST_DOMAIN=$(head -n 1 "$SUB_FILE")
    cloud_enum -k "$FIRST_DOMAIN" -l "$OUTPUT_DIR/buckets.txt" | notify -p discord -bulk
fi

# --- Phase 2: Merge & Port Scan ---
echo "[*] Phase 2: Merging All Assets & Port Scanning..."
# 合併所有來源：Root file, Amass 產出, Subfinder 產出
cat "$ROOT_FILE" "$OUTPUT_DIR/amass_subs.txt" "$OUTPUT_DIR/subfinder_subs.txt" 2>/dev/null | sort -u > "$OUTPUT_DIR/all_targets.txt"

naabu -list "$OUTPUT_DIR/all_targets.txt" -top-ports 1000 -silent -o "$OUTPUT_DIR/naabu.txt" | notify -p discord -bulk

# --- Phase 3: Probing & 403 Bypass ---
echo "[*] Phase 3: Probing & 403 Bypass Testing..."
cat "$OUTPUT_DIR/all_targets.txt" "$OUTPUT_DIR/naabu.txt" | sort -u > "$OUTPUT_DIR/to_httpx.txt"
httpx-toolkit -l "$OUTPUT_DIR/to_httpx.txt" -fc 404 -silent -o "$OUTPUT_DIR/alive.txt"

# 403 Bypass Alert
grep "403" "$OUTPUT_DIR/alive.txt" | xargs -I % curl -s -I -H "X-Forwarded-For: 127.0.0.1" % | grep "200 OK" && echo "[!] 403 Bypass SUCCESS on %" | notify -p discord

# --- Phase 4: JS Secret Mining (Trufflehog) ---
echo "[*] Phase 4: Crawling & Verified Secret Mining..."
katana -list "$OUTPUT_DIR/alive.txt" -jc -kf all -d 3 -fs rdn -o "$OUTPUT_DIR/urls.txt"

grep ".js" "$OUTPUT_DIR/urls.txt" | sort -u > "$OUTPUT_DIR/js_urls.txt"
trufflehog pipeline --file="$OUTPUT_DIR/js_urls.txt" --only-verified > "$OUTPUT_DIR/secrets/js_secrets.txt"

if [ -s "$OUTPUT_DIR/secrets/js_secrets.txt" ]; then
    echo "[!!!] FOUND VERIFIED SECRETS - CHECK DISCORD" | notify -p discord
    cat "$OUTPUT_DIR/secrets/js_secrets.txt" | notify -p discord
fi

# --- Phase 5: Money-Maker Nuclei Scan ---
echo "[*] Phase 5: High-ROI Nuclei Templates..."
cat "$OUTPUT_DIR/urls.txt" | nuclei \
    -as \
    -t takeovers/ \
    -t cves/2024/,cves/2025/,cves/2026/ \
    -t default-logins/ \
    -t exposures/ \
    -severity medium,high,critical \
    -rl 50 -bs 15 -silent -o "$OUTPUT_DIR/nuclei_bounty.txt" | notify -p discord -bulk

# --- Phase 6: BBOT Heavy Sweep ---
echo "[*] Phase 6: BBOT Kitchen Sink..."
bbot -t "$OUTPUT_DIR/all_targets.txt" -p kitchen-sink --allow-deadly --force | notify -p discord -bulk

echo "[+] BlackTrack Finished. Good luck with the Bounty!" | notify -p discord
