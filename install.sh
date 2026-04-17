#!/bin/bash
# Hunter : Jake Lo (JakeLo.ai)
# Project: BlackTrack Pipeline - Money Maker Installer
# Updated: 2026-04-18
# Description: 針對 BlackTrack v6.5 腳本需求進行優化

set -e # 出錯即停止

echo "[*] Initializing environment for Jake Lo's BlackTrack (The Money Maker) on Kali..."

# 1. 系統核心工具與 Kali Repo 內置工具
echo "[*] Installing core dependencies and repo-based tools..."
sudo apt-get update
sudo apt-get install -y proxychains4 curl git jq python3 python3-pip golang-go \
    httpx-toolkit subfinder nuclei amass feroxbuster unzip -y

# 2. 安裝 Trufflehog (Secret Mining 核心)
echo "[*] Installing Trufflehog..."
if ! command -v trufflehog &> /dev/null; then
    curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b /usr/local/bin
fi

# 3. Go-based 工具安裝 (包含 v6.5 新增的 tlsx)
echo "[*] Installing latest Go binaries (ProjectDiscovery Suite)..."
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# 確保 Go 預設路徑存在
mkdir -p ~/go/bin

# 安裝 BlackTrack v6.5 必備工具
go install -v github.com/projectdiscovery/katana/cmd/katana@latest
go install -v github.com/projectdiscovery/notify/cmd/notify@latest
go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
go install -v github.com/projectdiscovery/tlsx/cmd/tlsx@latest

# 4. Python-based 工具 (BBOT & Semgrep)
echo "[*] Installing BBOT and Semgrep..."
# 使用 --upgrade 確保是最新版以符合 v6.5 的 kitchen-sink 參數
python3 -m pip install --upgrade bbot semgrep --break-system-packages

# 5. 二進制文件與路徑設置
echo "[*] Linking binaries to /usr/local/bin..."
# 將 Go 安裝的工具軟連結到系統路徑，確保 sudo 環境也能執行
sudo ln -sf ~/go/bin/katana /usr/local/bin/katana
sudo ln -sf ~/go/bin/notify /usr/local/bin/notify
sudo ln -sf ~/go/bin/naabu /usr/local/bin/naabu
sudo ln -sf ~/go/bin/tlsx /usr/local/bin/tlsx

# 6. Nuclei Templates 同步與自定義模板整合
echo "[*] Setting up Nuclei Templates..."
nuclei -ut # 更新官方模板
mkdir -p ~/nuclei-templates
if [ -d "./black-nuclei" ]; then
    cp -r ./black-nuclei/* ~/nuclei-templates/
    echo "[+] Black-nuclei custom templates merged."
fi

# 7. 設置 BlackTrack 與助手腳本權限
echo "[*] Setting up BlackTrack execution permissions..."
chmod +x blacktrack.sh
if [ -f "proxy_manager.sh" ]; then
    chmod +x proxy_manager.sh
fi

# 建立全域軟連結，方便隨時隨地執行
sudo ln -sf "$(pwd)/blacktrack.sh" /usr/local/bin/blacktrack

# 8. 預檢查配置文件
echo "[*] Final environment check..."
if [ ! -d "~/.config/notify" ]; then
    echo "[!] Warning: Notify config folder not found. Please run 'notify' once to initialize."
fi

# --- 重要提示 ---
echo "--------------------------------------------------"
echo "[+] Installation complete. Ready to hunt."
echo "[!] CRITICAL: You MUST configure your Discord Webhook in:"
echo "    ~/.config/notify/provider.yaml"
echo "[!] Ensure 'proxy_manager.sh' is in the same folder as blacktrack.sh"
echo "--------------------------------------------------"
