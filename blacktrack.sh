#!/bin/bash

# --- Help Menu ---
show_help() {
    echo "Usage: ./blacktrack.sh [options]"
    echo "Options:"
    echo "  -r <file>    Root Domain file (Single assets, skip subdomain discovery)"
    echo "  -s <file>    Subdomain targets (Run Subfinder for wildcard scope)"
    echo "  -a <file>    Amass deep brute targets (Optional, takes long time)"
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
OUTPUT_DIR="fast_bounty_$DATE"
mkdir -p "$OUTPUT_DIR/secrets" "$OUTPUT_DIR/amass_raw"

# --- Phase 1: Fast Passive Recon (The Mapping) ---
echo "[*] Phase 1: Mapping Attack Surface (Subfinder)..." | notify -p discord
if [[ -n "$SUB_FILE" ]]; then
    subfinder -dL "$SUB_FILE" -silent -o "$OUTPUT_DIR/passive_subs.txt"
fi

# 合併 Root 同埋 Passive 搵到嘅所有 Subdomains
cat "$ROOT_FILE" "$OUTPUT_DIR/passive_subs.txt" 2>/dev/null | sort -u > "$OUTPUT_DIR/quick_targets.txt"
TOTAL_QUICK=$(wc -l < "$OUTPUT_DIR/quick_targets.txt")
echo "[+] Mapping Done. Total Quick Targets: $TOTAL_QUICK" | notify -p discord

# --- Phase 2: Fast-Money Nuclei (The Low-Hanging Fruit) ---
# 呢一炮係同其他人「搶時間」，專攻最易爆嘅 P1/P2
echo "[!] Phase 2: Launching Quick-Win Nuclei Scan..." | notify -p discord
httpx-toolkit -l "$OUTPUT_DIR/quick_targets.txt" -silent | nuclei \
    -t takeovers/ \
    -t exposures/ \
    -t misconfig/ \
    -severity critical,high \
    -rl 100 -bs 25 \
    -silent -o "$OUTPUT_DIR/quick_win_results.txt" | notify -p discord

# --- Phase 3: Deep Recon - Amass Brute Force (Concurrent) ---
# 呢部分好慢，所以擺喺 Quick Win 之後
if [[ -n "$AMASS_FILE" ]]; then
    echo "[*] Phase 3: Starting Deep Amass Brute Force (Slow)..." | notify -p discord
    sort -u "$AMASS_FILE" | while read -r domain; do
        [ -z "$domain" ] && continue
        amass enum -d "$domain" -brute -w "$WORDLIST" -oA "$OUTPUT_DIR/amass_raw/${domain}_full"
    done
    cat "$OUTPUT_DIR/amass_raw/"*.txt | sort -u > "$OUTPUT_DIR/amass_subs.txt"
fi

# --- Phase 4: Full Asset Consolidation & Port Scan ---
cat "$OUTPUT_DIR/quick_targets.txt" "$OUTPUT_DIR/amass_subs.txt" 2>/dev/null | sort -u > "$OUTPUT_DIR/all_assets.txt"
naabu -list "$OUTPUT_DIR/all_assets.txt" -top-ports 1000 -silent -o "$OUTPUT_DIR/naabu.txt" | notify -p discord -bulk

# --- Phase 5: Deep Probing & Secret Mining ---
# 針對所有 Asset 進行深入挖掘
httpx-toolkit -l "$OUTPUT_DIR/naabu.txt" -fc 404 -silent -o "$OUTPUT_DIR/alive.txt"
katana -list "$OUTPUT_DIR/alive.txt" -jc -kf all -d 3 -fs rdn -o "$OUTPUT_DIR/urls.txt"

# Trufflehog 掃描 JS Secrets
grep ".js" "$OUTPUT_DIR/urls.txt" | sort -u > "$OUTPUT_DIR/js_urls.txt"
trufflehog pipeline --file="$OUTPUT_DIR/js_urls.txt" --only-verified > "$OUTPUT_DIR/secrets/js_secrets.txt" | notify -p discord

# --- Phase 6: Full Nuclei & BBOT Sweep ---
# 跑埋剩低嘅漏洞，包括最近幾年嘅 CVE
cat "$OUTPUT_DIR/urls.txt" | nuclei \
    -as -t cves/2024/,cves/2025/,cves/2026/ -t default-logins/ \
    -severity medium,high,critical -rl 50 -silent -o "$OUTPUT_DIR/full_nuclei_results.txt" | notify -p discord -bulk

bbot -t "$OUTPUT_DIR/all_assets.txt" -p kitchen-sink --allow-deadly --force | notify -p discord -bulk

echo "[+] BlackTrack Finished. Results in $OUTPUT_DIR" | notify -p discord
