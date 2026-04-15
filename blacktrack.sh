#!/bin/bash

# --- BlackTrack Tactical Banner ---
echo -e "\e[1;31m"
echo "  ____  _         _    ____ _  _______ ____      _    ____ _  __"
echo " | __ )| |       / \  / ___| |/ /_  _|  _ \    / \  / ___| |/ /"
echo " |  _ \| |      / _ \| |   | ' /  | | | |_) |  / _ \| |   | ' / "
echo " | |_) | |___  / ___ \ |___| . \  | | |  _ <  / ___ \ |___| . \ "
echo " |____/|_____/_/   \_\____|_|\_\ |_| |_| \_\/_/   \_\____|_|\_\\"
echo -e "\e[0m"
echo "        >> JAKELO.AI WEAPONIZED RECON ENGINE v1.0.0 <<"
echo -e "\e[1;31m        >> [ HUNTER MODE: ACTIVE ] <<\e[0m"
echo "---------------------------------------------------------------"
echo ""

# --- Color Definitions ---
G=''
R=''
Y=''
NC=''

# --- Variable Initialization ---
TARGET_FILE=$1
DATE=$(date +%Y%m%d_%H%M)
OUTPUT_DIR="recon_$DATE"
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="$OUTPUT_DIR/nuclei_results.txt"

# --- Input Validation ---
if [ -z "$TARGET_FILE" ]; then
    echo -e "${R}Usage: ./blacktrack.sh targets.txt${NC}"
    exit 1
fi

echo -e "${G}[+] Initializing BlackTrack Pipeline: $TARGET_FILE${NC}"
echo -e "${Y}[!] Results will be saved in: $OUTPUT_DIR${NC}"

# --- Phase 1: Subdomain Discovery ---
echo -e "${G}[*] Phase 1: Passive Subdomain Enumeration (Subfinder)...${NC}"
subfinder -dL "$TARGET_FILE" -all -recursive -silent -o "$OUTPUT_DIR/subs.txt"

# --- Phase 2: Live Host Probing ---
echo -e "${G}[*] Phase 2: Identifying Alive Hosts (Httpx)...${NC}"
cat "$OUTPUT_DIR/subs.txt" | httpx-toolkit -silent -fc 404 -o "$OUTPUT_DIR/alive.txt"

# --- Phase 3: Endpoint Discovery ---
echo -e "${G}[*] Phase 3: Deep Crawling (Katana)...${NC}"
cat "$OUTPUT_DIR/alive.txt" | katana -silent -jc -kf all -d 3 -fs rdn -o "$OUTPUT_DIR/urls.txt"

# Phase 4: Running Nuclei with ALL templates (Official + Community + JakeLo)
cat "$OUTPUT_DIR/urls.txt" | nuclei \
    -t ~/nuclei-templates \
    -as \
    -itags exploit,cve,lfi,ssrf,sqli,rce,config \
    -severity critical,high \
    -rl 100 -bs 25 -c 15 \
    -et tags/dos \
    -silent -stream -o "$OUTPUT_FILE" | notify -p discord -bulk

echo -e "${G}[+] BlackTrack Pipeline Finished. Check Discord or $OUTPUT_FILE for findings.${NC}"
