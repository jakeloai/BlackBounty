#!/bin/bash
# proxy_manager.sh

PROXY_POOL="proxy_pool.txt"
TEMP_RAW="proxies_raw.txt"
TEMP_VALID="proxies_valid.tmp"

check_proxy() {
    local proxy=$1
    if curl -s -o /dev/null -L --proxy "$proxy" --max-time 3 "https://www.google.com" -w "%{http_code}" | grep -q "200"; then
        echo "$proxy" >> "$TEMP_VALID"
    fi
}

export -f check_proxy

while true; do
    echo "[*] $(date): Refreshing proxy pool..."
    
    # Fetch HTTP/HTTPS/SOCKS4/SOCKS5 lists from proxifly
    curl -s "https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/http/data.txt" > "$TEMP_RAW"
    curl -s "https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/https/data.txt" >> "$TEMP_RAW"
    curl -s "https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/socks4/data.txt" | sed 's/^/socks4:\/\//' >> "$TEMP_RAW"
    curl -s "https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/socks5/data.txt" | sed 's/^/socks5:\/\//' >> "$TEMP_RAW"

    > "$TEMP_VALID"

    # Parallel checking using xargs
    sort -u "$TEMP_RAW" | xargs -I {} -P 50 bash -c 'check_proxy "{}"'

    # Atomic update to avoid breaking active Nuclei scans
    if [ -s "$TEMP_VALID" ]; then
        mv "$TEMP_VALID" "$PROXY_POOL"
        echo "[+] Proxy pool updated. Alive proxies: $(wc -l < $PROXY_POOL)"
    else
        echo "[-] No alive proxies found in this run. Keeping old pool."
    fi

    # Random sleep between 5 to 15 minutes (300 to 900 seconds)
    SLEEP_TIME=$((RANDOM % 601 + 300))
    echo "[*] Next update in $SLEEP_TIME seconds..."
    sleep $SLEEP_TIME
done
