#!/bin/bash
# Hunter : Jake

echo "[*] Installing BlackBounty dependencies..."

# System dependencies
sudo apt-get update
sudo apt-get install -y proxychains4 curl git jq python3 golang

# ProjectDiscovery tools
echo "[*] Installing Go-based security tools..."
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install -v github.com/projectdiscovery/notify/cmd/notify@latest

# Global access setup
sudo cp ~/go/bin/* /usr/local/bin/

# Script setup
chmod +x BlackBounty.sh
sudo cp BlackBounty.sh /usr/local/bin/blackbounty

echo "[+] Installation complete. Use 'blackbounty <targets.txt>' to begin."
