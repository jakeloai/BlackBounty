#!/bin/bash
# Hunter : Jake

# --- Configuration & Initialization ---
TARGET_FILE=$1
OUTPUT_DIR="bounty_output"
NOTIFY_CONFIG="$HOME/.config/notify/provider-config.yaml"

# Ensure target file is provided
if [ -z "$TARGET_FILE" ]; then
    echo "[!] Usage: blackbounty <targets.txt>"
    exit 1
fi

# --- Stage: Notify Setup Check ---
if [ ! -f "$NOTIFY_CONFIG" ]; then
    echo "[!] Notify configuration not found at $NOTIFY_CONFIG"
    read -p "[?] Would you like to set up Discord notifications now? (y/n): " setup_now
    if [[ "$setup_now" == "y" ]]; then
        mkdir -p "$(dirname "$NOTIFY_CONFIG")"
        read -p "[>] Enter your Discord Webhook ID (e.g., blackbounty-alerts): " discord_id
        read -p "[>] Enter your Discord Webhook URL: " discord_url
        
        cat << EOF > "$NOTIFY_CONFIG"
discord:
  - id: "$discord_id"
    discord_channel_id: "none"
    discord_webhook_url: "$discord_url"
EOF
        echo "[+] Notify configuration saved to $NOTIFY_CONFIG"
    else
        echo "[!] Skipping notification setup. Results will only be saved locally."
    fi
else
    echo "[+] Existing Notify configuration detected."
    read -p "[?] Do you want to use/confirm existing settings? (y/n): " use_existing
    if [[ "$use_existing" != "y" ]]; then
        echo "[!] Please manually edit $NOTIFY_CONFIG or delete it to reset, then restart."
        exit 1
    fi
fi

# --- Stage 0: Proxy Gathering & Data Cleaning ---
mkdir -p "$OUTPUT_DIR"
RAW_PROXIES="$OUTPUT_DIR/raw_proxies.txt"
VALID_PROXIES="$OUTPUT_DIR/valid_proxies.txt"
PROXYCHAINS_CONF="$OUTPUT_DIR/proxychains_dynamic.conf"

echo "[*] Stage 0: Gathering proxies from GitHub sources..."
> "$RAW_PROXIES"

# Source: Proxifly
curl -s "https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/http/data.txt" | sed 's/^/http:\/\//' >> "$RAW_PROXIES"
curl -s "https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/socks4/data.txt" | sed 's/^/socks4:\/\//' >> "$RAW_PROXIES"
curl -s "https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/socks5/data.txt" | sed 's/^/socks5:\/\//' >> "$RAW_PROXIES"

# Source: TheSpeedX
curl -s "https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/http.txt" | sed 's/^/http:\/\//' >> "$RAW_PROXIES"
curl -s "https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/socks4.txt" | sed 's/^/socks4:\/\//' >> "$RAW_PROXIES"
curl -s "https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/socks5.txt" | sed 's/^/socks5:\/\//' >> "$RAW_PROXIES"

sort -u "$RAW_PROXIES" -o "$RAW_PROXIES"
echo "[+] Total unique proxies gathered: $(wc -l < "$RAW_PROXIES")"

# Validate proxies
echo "[*] Validating proxies (Timeout: 5s, Threads: 50)..."
> "$VALID_PROXIES"
cat "$RAW_PROXIES" | xargs -P 50 -I {} sh -c 'curl -s -x {} --connect-timeout 5 https://1.1.1.1 >/dev/null && echo {}' >> "$VALID_PROXIES"

VALID_COUNT=$(wc -l < "$VALID_PROXIES")
echo "[+] Valid proxies available: $VALID_COUNT"

if [ "$VALID_COUNT" -eq 0 ]; then
    echo "[!] No valid proxies found. Exiting to protect your local IP."
    exit 1
fi

# Generate Dynamic Proxychains Config
cat << EOF > "$PROXYCHAINS_CONF"
dynamic_chain
proxy_dns
tcp_read_time_out 10000
tcp_connect_time_out 5000
[ProxyList]
EOF
sed -E 's/(socks5|http|socks4):\/\/([^:]+):([0-9]+)/\1 \2 \3/' "$VALID_PROXIES" >> "$PROXYCHAINS_CONF"

# --- Stage 1: Subdomain Enumeration ---
echo "[*] Stage 1: Subdomain Enumeration (Subfinder)..."
SUBS_RAW="$OUTPUT_DIR/01_subs_raw.txt"
proxychains4 -f "$PROXYCHAINS_CONF" subfinder -dL "$TARGET_FILE" -all -silent > "$SUBS_RAW"
sort -u "$SUBS_RAW" -o "$SUBS_RAW"
echo "[+] Subdomains discovered: $(wc -l < "$SUBS_RAW")"

# --- Stage 2: Alive Hosts Detection ---
echo "[*] Stage 2: Probing alive hosts (HTTPX)..."
ALIVE_HOSTS="$OUTPUT_DIR/02_alive_hosts.txt"
# Using httpx native proxy-list for performance
httpx-toolkit -l "$SUBS_RAW" -proxy-list "$VALID_PROXIES" -threads 50 -silent -o "$ALIVE_HOSTS"
echo "[+] Active hosts found: $(wc -l < "$ALIVE_HOSTS")"

# --- Stage 3: Vulnerability Scanning & Alerts ---
echo "[*] Stage 3: Scanning for vulnerabilities (Nuclei)..."
VULNS_RESULT="$OUTPUT_DIR/03_vulns.txt"

if [ -f "$NOTIFY_CONFIG" ]; then
    # Run Nuclei and pipe critical/high/medium results to Discord
    proxychains4 -f "$PROXYCHAINS_CONF" nuclei -l "$ALIVE_HOSTS" \
        -as -severity low,medium,high,critical -stats \
        -o "$VULNS_RESULT" -silent | notify
else
    proxychains4 -f "$PROXYCHAINS_CONF" nuclei -l "$ALIVE_HOSTS" \
        -as -severity low,medium,high,critical -stats \
        -o "$VULNS_RESULT"
fi

echo "--------------------------------------------------"
echo "[+] BlackBounty Hunting Session Finished."
echo "[+] Results saved in: $OUTPUT_DIR/"
echo "Hunter : Jake"
