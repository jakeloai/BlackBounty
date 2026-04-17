#!/bin/bash
# Hunter : Jake Lo (JakeLo.ai)
# Project: BlackTrack Pipeline - Money Maker Installer
# Updated: 2026-04-18
# Version: 1.2.0 - Portable Edition

set -e # Exit on error

echo "[*] Initializing environment for Jake Lo's BlackTrack (The Money Maker) on Kali..."

# 1. System Core Tools and Kali Repo Tools
echo "[*] Installing core dependencies and repo-based tools..."
sudo apt-get update
sudo apt-get install -y proxychains4 curl git jq python3 python3-pip golang-go \
    httpx-toolkit subfinder nuclei amass feroxbuster unzip -y

# 2. Install Trufflehog (Secret Mining Core)
echo "[*] Installing Trufflehog..."
if ! command -v trufflehog &> /dev/null; then
    curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b /usr/local/bin
fi

# 3. Go-based Tools (ProjectDiscovery Suite)
echo "[*] Installing latest Go binaries..."
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
mkdir -p ~/go/bin

# Installing BlackTrack v6.5 required binaries
go install -v github.com/projectdiscovery/katana/cmd/katana@latest
go install -v github.com/projectdiscovery/notify/cmd/notify@latest
go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
go install -v github.com/projectdiscovery/tlsx/cmd/tlsx@latest

# 4. Python-based Tools (BBOT & Semgrep)
echo "[*] Installing BBOT and Semgrep..."
python3 -m pip install --upgrade bbot --break-system-packages

# 5. Path Management & Binary Linking
echo "[*] Linking binaries to /usr/local/bin for global access..."
sudo ln -sf ~/go/bin/katana /usr/local/bin/katana
sudo ln -sf ~/go/bin/notify /usr/local/bin/notify
sudo ln -sf ~/go/bin/naabu /usr/local/bin/naabu
sudo ln -sf ~/go/bin/tlsx /usr/local/bin/tlsx

# 6. Nuclei Templates Synchronization
echo "[*] Setting up Nuclei Templates..."
nuclei -ut
mkdir -p ~/nuclei-templates
if [ -d "./black-nuclei" ]; then
    cp -r ./black-nuclei/* ~/nuclei-templates/
    echo "[+] Custom black-nuclei templates merged into ~/nuclei-templates/"
fi

# 7. Setting Permissions and Global Command
echo "[*] Configuring execution permissions..."
INSTALL_DIR="$(pwd)"
chmod +x "$INSTALL_DIR/blacktrack.sh"
if [ -f "$INSTALL_DIR/proxy_manager.sh" ]; then
    chmod +x "$INSTALL_DIR/proxy_manager.sh"
fi

# Create a global symlink for BlackTrack
sudo ln -sf "$INSTALL_DIR/blacktrack.sh" /usr/local/bin/blacktrack

# 8. Environment Check
echo "[*] Performing final environment validation..."
if [ ! -d "$HOME/.config/notify" ]; then
    echo "[!] Warning: Notify config not found. Run 'notify' once to generate provider.yaml"
fi

# --- Summary ---
echo "--------------------------------------------------"
echo "[+] Installation complete. BlackTrack is now global."
echo "[+] You can now run 'blacktrack' from any directory."
echo "[!] IMPORTANT: Ensure proxy_manager.sh remains in:"
echo "    $INSTALL_DIR"
echo "[!] Configure your Discord Webhook in:"
echo "    ~/.config/notify/provider.yaml"
echo "--------------------------------------------------"
