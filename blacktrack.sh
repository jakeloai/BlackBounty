#!/bin/bash

# --- Color Definitions ---
G='\033[0;32m'
R='\033[0;31m'
Y='\033[1;33m'
NC='\033[0m'

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
cat "$OUTPUT_DIR/subs.txt" | httpx -silent -fc 404,403 -o "$OUTPUT_DIR/alive.txt"

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
