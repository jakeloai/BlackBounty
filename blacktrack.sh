#!/bin/bash

# --- Help Menu ---
show_help() {
    echo "Usage: ./blacktrack.sh [options]"
    echo "Options:"
    echo "  -r <file>    Root Domain file (Directly to httpx)"
    echo "  -s <file>    Subdomain file (Target for Amass/Subfinder)"
    echo "  -w <file>    Wordlist for Amass brute forcing"
    echo "  -h           Show help"
    exit 0
}

# --- Argument Parsing ---
WORDLIST="/usr/share/wordlists/amass/subdomains-top1mil.txt" # 預設路徑
while getopts "r:s:w:h" opt; do
    case $opt in
        r) ROOT_FILE=$OPTARG ;;
        s) SUB_FILE=$OPTARG ;;
        w) WORDLIST=$OPTARG ;;
        h) show_help ;;
        *) show_help ;;
    esac
done

if [[ -z "$ROOT_FILE" && -z "$SUB_FILE" ]]; then show_help; fi

# --- Initialization ---
DATE=$(date +%Y%m%d_%H%M)
OUTPUT_DIR="money_recon_$DATE"
mkdir -p "$OUTPUT_DIR/secrets" "$OUTPUT_DIR/amass_raw"

# --- Phase 0: Amass Deep Enumeration (The Beginning) ---
if [[ -n "$SUB_FILE" ]]; then
    echo "[*] Phase 0: Starting Amass Brute Force & Enum..." | notify -p discord
    # 遍歷文件入面嘅 domain 行 Amass
    while read -r domain; do
        [ -z "$domain" ] && continue
        echo "[>] Enumerating: $domain"
        # -brute: 強力暴力破解, -d: 指定域名, -oA: 輸出所有格式
        amass enum -d "$domain" -brute -w "$WORDLIST" -oA "$OUTPUT_DIR/amass_raw/${domain}_full"
    done < "$SUB_FILE"
    
    # 提取所有搵到嘅 subdomains
    cat "$OUTPUT_DIR/amass_raw/"*.txt | sort -u > "$OUTPUT_DIR/amass_subs.txt"
    echo "[+] Amass finished. Found $(wc -l < "$OUTPUT_DIR/amass_subs.txt") subdomains." | notify -p discord
fi

# --- Phase 1: Subfinder & Cloud Discovery ---
if [[ -n "$SUB_FILE" ]]; then
    echo "[*] Phase 1: Running Subfinder & Cloud Enum..."
    subfinder -dL "$SUB_FILE" -silent -o "$OUTPUT_DIR/subfinder_subs.txt"
    
    # 賺錢功能 1: Cloud Storage Leakage
    FIRST_DOMAIN=$(head -n 1 "$SUB_FILE")
    cloud_enum -k "$FIRST_DOMAIN" -l "$OUTPUT_DIR/buckets.txt" | notify -p discord -bulk
fi

# --- Phase 2: Merge & Port Scan ---
echo "[*] Phase 2: Merging & Port Scanning..."
cat "$ROOT_FILE" "$OUTPUT_DIR/amass_subs.txt" "$OUTPUT_DIR/subfinder_subs.txt" 2>/dev/null | sort -u > "$OUTPUT_DIR/all_targets.txt"
naabu -list "$OUTPUT_DIR/all_targets.txt" -top-ports 1000 -silent -o "$OUTPUT_DIR/naabu.txt" | notify -p discord -bulk

# --- Phase 3: Probing & 403 Bypass ---
echo "[*] Phase 3: Probing & 403 Bypass..."
cat "$OUTPUT_DIR/all_targets.txt" "$OUTPUT_DIR/naabu.txt" | sort -u > "$OUTPUT_DIR/to_httpx.txt"
httpx-toolkit -l "$OUTPUT_DIR/to_httpx.txt" -fc 404 -silent -o "$OUTPUT_DIR/alive.txt"

# 賺錢功能 2: 403 Bypass 自動化
grep "403" "$OUTPUT_DIR/alive.txt" | xargs -I % curl -s -I -H "X-Forwarded-For: 127.0.0.1" % | grep "200 OK" && echo "[!] 403 Bypass Found on %" | notify -p discord

# --- Phase 4: JS Secret Mining (Trufflehog) ---
echo "[*] Phase 4: Crawling & Secret Mining..."
katana -list "$OUTPUT_DIR/alive.txt" -jc -kf all -d 3 -fs rdn -o "$OUTPUT_DIR/urls.txt"

# 賺錢功能 3: Trufflehog 掃描 JS Secrets
grep ".js" "$OUTPUT_DIR/urls.txt" | sort -u > "$OUTPUT_DIR/js_urls.txt"
trufflehog pipeline --file="$OUTPUT_DIR/js_urls.txt" --only-verified > "$OUTPUT_DIR/secrets/js_secrets.txt"
if [ -s "$OUTPUT_DIR/secrets/js_secrets.txt" ]; then
    echo "[!!!] VERIFIED SECRETS FOUND!" | notify -p discord
    cat "$OUTPUT_DIR/secrets/js_secrets.txt" | notify -p discord
fi

# --- Phase 5: High-ROI Nuclei Scanning ---
echo "[*] Phase 5: Running Nuclei (Money Templates)..."
cat "$OUTPUT_DIR/urls.txt" | nuclei \
    -as \
    -t takeovers/ \
    -t cves/2024/,cves/2025/,cves/2026/ \
    -t default-logins/ \
    -t exposures/ \
    -severity medium,high,critical \
    -rl 50 -bs 15 -silent -o "$OUTPUT_DIR/nuclei_bounty.txt" | notify -p discord -bulk

# --- Phase 6: Heavy Recon (BBOT) ---
echo "[*] Phase 6: BBOT Final Sweep..."
bbot -t "$OUTPUT_DIR/all_targets.txt" -p kitchen-sink --allow-deadly --force | notify -p discord -bulk

echo "[+] Done! All results in $OUTPUT_DIR" | notify -p discord
