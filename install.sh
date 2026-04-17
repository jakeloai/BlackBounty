#!/bin/bash
# Hunter : Jake Lo (JakeLo.ai)
# Project: BlackTrack Pipeline - Money Maker Installer
# Updated: 2026-04-17

set -e # 出錯即停止

echo "[*] Initializing environment for Jake Lo's BlackTrack (The Money Maker) on Kali..."

# 1. 系統核心工具與 Kali Repo 內置工具
echo "[*] Installing core dependencies and repo-based tools..."
sudo apt-get update
sudo apt-get install -y proxychains4 curl git jq python3 python3-pip golang-go \
    httpx-toolkit subfinder nuclei cloud-enum amass feroxbuster unzip -y

# 2. 安裝 Trufflehog (Secret Mining 核心)
echo "[*] Installing Trufflehog (Verified Secrets Scanner)..."
if ! command -v trufflehog &> /dev/null; then
    curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b /usr/local/bin
fi

# 3. Go-based 搵食工具 (最新開發版)
echo "[*] Installing latest Go binaries (ProjectDiscovery Suite)..."
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

go install -v github.com/projectdiscovery/katana/cmd/katana@latest
go install -v github.com/projectdiscovery/notify/cmd/notify@latest
go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest

# 4. Python-based 重型工具 (BBOT & Semgrep)
echo "[*] Installing BBOT and Semgrep..."
# BBOT 係廚房洗碗槽級別嘅工具，必須要有
python3 -m pip install bbot semgrep --break-system-packages

# 5. 二進制文件與路徑設置
echo "[*] Linking binaries to /usr/local/bin..."
sudo cp ~/go/bin/* /usr/local/bin/ 2>/dev/null || true

# 6. Nuclei Templates 同步與自定義模板整合
echo "[*] Setting up Nuclei Templates..."
nuclei -ut # 先更新官方模板
mkdir -p ~/nuclei-templates
if [ -d "./black-nuclei" ]; then
    cp -r ./black-nuclei/* ~/nuclei-templates/
    echo "[+] Black-nuclei custom templates merged."
fi

# 7. 設置 BlackTrack 執行權限
chmod +x blacktrack.sh
sudo ln -sf "$(pwd)/blacktrack.sh" /usr/local/bin/blacktrack

# --- 重要提示 ---
echo "--------------------------------------------------"
echo "[+] Installation complete. Ready to hunt."
echo "[!] REMINDER: Configure your Discord Webhook in:"
echo "    ~/.config/notify/provider.yaml"
echo "--------------------------------------------------"
