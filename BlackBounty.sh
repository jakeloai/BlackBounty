#!/bin/bash
# Hunter : Jake

# --- Configuration & Initialization ---
TARGET_FILE=$1
OUTPUT_DIR="bounty_output"

if [ -z "$TARGET_FILE" ]; then
    echo "[!] Usage: ./BlackBounty.sh <targets.txt>"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
RAW_PROXIES="$OUTPUT_DIR/raw_proxies.txt"
VALID_PROXIES="$OUTPUT_DIR/valid_proxies.txt"
PROXYCHAINS_CONF="$OUTPUT_DIR/proxychains_dynamic.conf"

SUBS_RAW="$OUTPUT_DIR/01_subs_raw.txt"
ALIVE_HOSTS="$OUTPUT_DIR/02_alive_hosts.txt"
VULNS_RESULT="$OUTPUT_DIR/03_vulns.txt"

echo "[+] Starting BlackBounty Pipeline..."
echo "[+] Target List: $TARGET_FILE"

# --- Stage 0: Proxy Gathering & Data Cleaning ---
echo "[*] Stage 0: Gathering proxies from GitHub..."
> "$RAW_PROXIES"

# Download and format proxies (Proxifly)
curl -s "https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/http/data.txt" | sed 's/^/http:\/\//' >> "$RAW_PROXIES"
curl -s "https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/socks4/data.txt" | sed 's/^/socks4:\/\//' >> "$RAW_PROXIES"
curl -s "https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/socks5/data.txt" | sed 's/^/socks5:\/\//' >> "$RAW_PROXIES"

# Download and format proxies (TheSpeedX)
curl -s "https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/http.txt" | sed 's/^/http:\/\//' >> "$RAW_PROXIES"
curl -s "https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/socks4.txt" | sed 's/^/socks4:\/\//' >> "$RAW_PROXIES"
curl -s "https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/socks5.txt" | sed 's/^/socks5:\/\//' >> "$RAW_PROXIES"

# Deduplicate
sort -u "$RAW_PROXIES" -o "$RAW_PROXIES"
echo "[+] Total unique proxies gathered: $(wc -l < "$RAW_PROXIES")"

# Validate proxies using lightweight parallel curl
echo "[*] Validating proxies (Timeout: 5s, Threads: 50)..."
> "$VALID_PROXIES"
cat "$RAW_PROXIES" | xargs -P 50 -I {} sh -c 'curl -s -x {} --connect-timeout 5 https://1.1.1.1 >/dev/null && echo {}' >> "$VALID_PROXIES"

VALID_COUNT=$(wc -l < "$VALID_PROXIES")
echo "[+] Valid and alive proxies: $VALID_COUNT"

if [ "$VALID_COUNT" -eq 0 ]; then
    echo "[!] No valid proxies found. Exiting to prevent direct IP exposure."
    exit 1
fi

# Generate dynamic proxychains.conf
echo "[*] Generating active proxychains configuration..."
cat << EOF > "$PROXYCHAINS_CONF"
dynamic_chain
proxy_dns
tcp_read_time_out 10000
tcp_connect_time_out 5000
[ProxyList]
EOF

# Convert URI format to proxychains format (e.g., socks5://1.2.3.4:1080 -> socks5 1.2.3.4 1080)
sed -E 's/(socks5|http|socks4):\/\/([^:]+):([0-9]+)/\1 \2 \3/' "$VALID_PROXIES" >> "$PROXYCHAINS_CONF"

# --- Stage 1: Subdomain Enumeration ---
echo "[*] Stage 1: Running Subfinder..."
proxychains4 -f "$PROXYCHAINS_CONF" subfinder -dL "$TARGET_FILE" -all -silent > "$SUBS_RAW"
sort -u "$SUBS_RAW" -o "$SUBS_RAW"
echo "[+] Subdomains found: $(wc -l < "$SUBS_RAW")"

# --- Stage 2: Alive Hosts Detection ---
echo "[*] Stage 2: Probing alive hosts with HTTPX..."
# Utilizing httpx native proxy-list feature for faster concurrency handling
httpx-toolkit -l "$SUBS_RAW" -proxy-list "$VALID_PROXIES" -threads 50 -silent -o "$ALIVE_HOSTS"
echo "[+] Alive hosts: $(wc -l < "$ALIVE_HOSTS")"

# --- Stage 3: Vulnerability Scanning ---
echo "[*] Stage 3: Scanning for vulnerabilities with Nuclei..."
# Routing nuclei through proxychains for complete protocol masking
proxychains4 -f "$PROXYCHAINS_CONF" nuclei -l "$ALIVE_HOSTS" -as -severity low,medium,high,critical -stats -o "$VULNS_RESULT"

echo "[+] BlackBounty pipeline completed successfully."
echo "[+] Check the $OUTPUT_DIR/ directory for results."
