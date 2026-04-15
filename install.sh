#!/bin/bash
# Hunter : Jake Lo (JakeLo.ai)
# Project: BlackTrack Pipeline

echo "[*] Installing BlackTrack dependencies..."

# 1. System dependencies
sudo apt-get update
sudo apt-get install -y proxychains4 curl git jq python3 golang-go

# 2. ProjectDiscovery tools (Latest Versions)
echo "[*] Installing Go-based security tools..."
sudo apt install httpx-toolkit subfinder nuclei -y
go install -v github.com/projectdiscovery/katana/cmd/katana@latest
go install -v github.com/projectdiscovery/notify/cmd/notify@latest

# 3. Global access setup
echo "[*] Setting up binary paths..."
sudo cp ~/go/bin/* /usr/local/bin/

# 4. Template Integration (JakeLo.ai Structure)
echo "[*] Integrating black-nuclei templates..."
# Create nuclei-templates directory if it doesn't exist
mkdir -p ~/nuclei-templates

# Copying specialized templates from the repo to the local nuclei folder
if [ -d "./black-nuclei" ]; then
    cp -r ./black-nuclei/* ~/nuclei-templates/
    echo "[+] Templates merged to ~/nuclei-templates/"
else
    echo "[!] Error: black-nuclei directory not found. Please run this script from the repo root."
fi

# 5. BlackTrack Engine setup
echo "[*] Finalizing BlackTrack engine..."
chmod +x blacktrack.sh
sudo cp blacktrack.sh /usr/local/bin/blacktrack

echo "[+] Installation complete."
echo "[!] Use 'blacktrack <targets.txt>' to begin the hunt."
