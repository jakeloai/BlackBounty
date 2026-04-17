#!/bin/bash
# proxy_manager.sh

PROXY_POOL="proxy_pool.txt"
TEMP_RAW="proxies_raw.txt"
TEMP_VALID="proxies_valid.tmp"

check_proxy() {
    local proxy=$1
    # Check if proxy is alive and fast (3s timeout)
    if curl -s -o /dev/null -L --proxy "$proxy" --max-time 3 "https://www.google.com" -w "%{http_code}" | grep -q "200"; then
        echo "$proxy" >> "$TEMP_VALID"
    fi
}

export -f check_proxy

while true; do
    echo "[*] $(date): Refreshing proxy pool..."
    
    # Fetch from proxifly
    curl -s "https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/http/data.txt" > "$TEMP_RAW"
    curl -s "https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/https/data.txt" >> "$TEMP_RAW"
    curl -s "https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/socks4/data.txt" | sed 's/^/socks4:\/\//' >> "$TEMP_RAW"
    curl -s "https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/socks5/data.txt" | sed 's/^/socks5:\/\//' >> "$TEMP_RAW"

    > "$TEMP_VALID"

    # Parallel checking
    sort -u "$TEMP_RAW" | xargs -I {} -P 50 bash -c 'check_proxy "{}"'

    # Atomic update
    if [ -s "$TEMP_VALID" ]; then
        mv "$TEMP_VALID" "$PROXY_POOL"
        echo "[+] Proxy pool updated: $(wc -l < $PROXY_POOL) alive."
    else
        echo "[-] No alive proxies. Keeping old pool."
    fi

    # Random sleep 5-15 mins
    sleep $((RANDOM % 601 + 300))
done#!/bin/bash
# blacktrack.sh - v6.0 Nuclear Edition (No Colors, Proxy Aware)

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

DATE=$(date +%Y%m%d_%H%M)
OUTPUT_DIR="scan_$DATE"
PROXY_POOL="proxy_pool.txt"
mkdir -p "$OUTPUT_DIR/amass_raw" "$OUTPUT_DIR/permutations"
PROCESSED_LOG="$OUTPUT_DIR/processed.log"

echo "[*] Starting BlackTrack v6.0 Pipeline..."

# Start proxy manager if not running
if ! pgrep -f proxy_manager.sh > /dev/null; then
    echo "[!] Starting proxy_manager.sh in background..."
    nohup ./proxy_manager.sh > proxy_manager.log 2>&1 &
else
    echo "[+] proxy_manager.sh is already running."
fi

# Ensure proxy pool has at least some entries before starting active scans
if [ ! -f "$PROXY_POOL" ]; then
    echo "[!] Waiting for initial proxy pool generation (approx 1-2 mins)..."
    while [ ! -f "$PROXY_POOL" ]; do sleep 5; done
fi

# --- Phase 1: Passive Subdomain Mapping (No Proxy Needed) ---
echo "[*] Phase 1: Passive Discovery..."
if [[ -n "$SUB_FILE" ]]; then
    subfinder -dL "$SUB_FILE" -silent -o "$OUTPUT_DIR/passive_subs.txt"
fi

# --- Phase 2: Recursive Amass Brute Force ---
if [[ -n "$AMASS_FILE" ]]; then
    echo "[*] Phase 2: Recursive Amass Brute Force..."
    sort -u "$AMASS_FILE" | while read -r domain; do
        [ -z "$domain" ] && continue
        if grep -q "^$domain$" "$PROCESSED_LOG" 2>/dev/null; then continue; fi

        echo "[>] Amass running on: $domain"
        amass enum -d "$domain" -brute -w "$WORDLIST" -recursive -oA "$OUTPUT_DIR/amass_raw/${domain}_deep" > /dev/null 2>&1
        echo "$domain" >> "$PROCESSED_LOG"
    done
    cat "$OUTPUT_DIR/amass_raw/"*.txt 2>/dev/null | sort -u > "$OUTPUT_DIR/amass_subs.txt"
fi

# --- Phase 3: Web Discovery & Crawling (No Proxy Needed) ---
echo "[*] Phase 3: Web Probing & Katana Crawling..."
cat "$ROOT_FILE" "$OUTPUT_DIR/passive_subs.txt" "$OUTPUT_DIR/amass_subs.txt" 2>/dev/null | sort -u > "$OUTPUT_DIR/base_assets.txt"

httpx-toolkit -l "$OUTPUT_DIR/base_assets.txt" -title -server -status-code -silent -o "$OUTPUT_DIR/alive_details.txt"
cat "$OUTPUT_DIR/alive_details.txt" | awk '{print $1}' > "$OUTPUT_DIR/alive.txt"

echo "[>] Running Katana Depth 5..."
katana -list "$OUTPUT_DIR/alive.txt" -jc -kf all -d 5 -fs rdn -silent -o "$OUTPUT_DIR/urls.txt"

# --- Phase 4: The "Nuclear" Active Scan (Rotating Proxies) ---
echo "[*] Phase 4: Nuclear Nuclei Scan with Rotating Proxies..."
# Using all templates (-t), random proxy rotation, mhe for dropped connections
nuclei -l "$OUTPUT_DIR/urls.txt" \
  -t ~/nuclei-templates/ \
  -proxy-file "$PROXY_POOL" \
  -proxy-mode random \
  -tlsi \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36" \
  -rl 20 \
  -c 5 \
  -timeout 10 \
  -retries 3 \
  -mhe 10 \
  -severity low,medium,high,critical \
  -stats -si 15 \
  -o "$OUTPUT_DIR/nuclear_results.txt" | notify -p discord -bulk -silent

# --- Phase 5: BBOT Kitchen-Sink ---
echo "[*] Phase 5: BBOT Kitchen-Sink Mode..."
bbot -t "$OUTPUT_DIR/alive.txt" -p kitchen-sink --allow-deadly --force > /dev/null 2>&1

echo "[+] BlackTrack pipeline finished successfully."
echo "[+] Results saved to: $OUTPUT_DIR/nuclear_results.txt"
