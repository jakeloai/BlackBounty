#!/bin/bash
# Hunter : Jake Lo (JakeLo.ai)
# Project: BlackTrack Pipeline

echo -e "\033[0;32m[*] Installing BlackTrack dependencies...\033[0m"

# 1. System dependencies
sudo apt-get update
sudo apt-get install -y proxychains4 curl git jq python3 golang-go

# 2. ProjectDiscovery tools (Latest Versions)
echo -e "\033[0;32m[*] Installing Go-based security tools...\033[0m\033[0;34m"
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/katana/cmd/katana@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install -v github.com/projectdiscovery/notify/cmd/notify@latest
echo -e "\033[0m"

# 3. Global access setup
echo -e "\033[0;32m[*] Setting up binary paths...\033[0m"
sudo cp ~/go/bin/* /usr/local/bin/

# 4. Template Integration (JakeLo.ai Structure)
echo -e "\033[0;32m[*] Integrating black-nuclei templates...\033[0m"
# Create nuclei-templates directory if it doesn't exist
mkdir -p ~/nuclei-templates

# Copying specialized templates from the repo to the local nuclei folder
if [ -d "./black-nuclei" ]; then
    cp -r ./black-nuclei/* ~/nuclei-templates/
    echo "[+] Templates merged to ~/nuclei-templates/"
else
    echo -e "\033[0;31m[!] Error: black-nuclei directory not found. Please run this script from the repo root.\033[0m"
fi

# 5. BlackTrack Engine setup
echo -e "\033[0;32m[*] Finalizing BlackTrack engine...\033[0m"
chmod +x blacktrack.sh
sudo cp blacktrack.sh /usr/local/bin/blacktrack

echo -e "\033[0;32m[+] Installation complete.\033[0m"
echo -e "\033[1;33m[!] Use 'blacktrack <targets.txt>' to begin the hunt.\033[0m"
