#!/bin/bash
# Hunter : Jake
# Installation script for BlackBounty environment

echo "[*] Initializing BlackBounty Environment Installation..."

# Update system
sudo apt-get update -y

# Install Core Dependencies
echo "[*] Installing Core Dependencies..."
sudo apt-get install -y proxychains4 curl git jq python3 python3-pip

# Install Go (Required for ProjectDiscovery tools)
if ! command -v go &> /dev/null; then
    echo "[*] Installing Go..."
    sudo apt-get install -y golang
    echo 'export GOPATH=$HOME/go' >> ~/.bashrc
    echo 'export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin' >> ~/.bashrc
    source ~/.bashrc
fi

# Install ProjectDiscovery Tools
echo "[*] Installing Subfinder, HTTPX, and Nuclei..."
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest

# Move Go binaries to /usr/local/bin for global access
sudo cp ~/go/bin/* /usr/local/bin/

# Setup BlackBounty Command
echo "[*] Setting up BlackBounty command..."
chmod +x BlackBounty.sh
sudo cp BlackBounty.sh /usr/local/bin/blackbounty

echo "[+] Installation Complete!"
echo "[+] You can now run 'blackbounty <targets.txt>' from any directory."
