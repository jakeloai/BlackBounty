#!/bin/bash
# Hunter : Jake Lo (JakeLo.ai)
# Project: BlackTrack Pipeline - Installer

echo "[*] Initializing environment for Jake Lo's BlackTrack on Kali..."

# 1. System & PD Tools (直接用 Kali repo 裝到嘅就用 apt)
sudo apt-get update
sudo apt-get install -y proxychains4 curl git jq python3 golang-go \
    httpx-toolkit subfinder nuclei cloud-enum trivy -y

# 2. Go-based tools (最新開發版)
echo "[*] Installing latest Go binaries..."
go install -v github.com/projectdiscovery/katana/cmd/katana@latest
go install -v github.com/projectdiscovery/notify/cmd/notify@latest
go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest

# 3. Semgrep Setup
echo "[*] Installing Semgrep..."
python3 -m pip install semgrep --break-system-packages

# 4. Binary & Path Setup
sudo cp ~/go/bin/* /usr/local/bin/

# 5. Templates Sync
mkdir -p ~/nuclei-templates
if [ -d "./black-nuclei" ]; then
    cp -r ./black-nuclei/* ~/nuclei-templates/
    echo "[+] Black-nuclei templates merged."
fi

# 6. Set execution bits
chmod +x blacktrack.sh
sudo cp blacktrack.sh /usr/local/bin/blacktrack

echo "[+] Installation complete. Let's make some money."
