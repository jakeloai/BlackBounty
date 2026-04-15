#!/bin/bash

# Color codes for output
G='\033[0;32m'
R='\033[0;31m'
NC='\033[0m'

TARGET_FILE=$1

# Check if input file is provided
if [ -z "$TARGET_FILE" ]; then
    echo -e "${R}Usage: ./blackbounty.sh targets.txt${NC}"
    exit 1
fi

echo -e "${G}[+] Initializing BlackBounty Pipeline for: $TARGET_FILE${NC}"

# Step 1: Subdomain Enumeration
echo -e "${G}[*] Phase 1: Passive Subdomain Discovery...${NC}"
subfinder -dL $TARGET_FILE -all -recursive -silent -o subs.txt

# Step 2: Live Host Probing
echo -e "${G}[*] Phase 2: Identifying Alive Hosts...${NC}"
cat subs.txt | httpx -silent -o alive.txt

# Step 3: Deep Crawling & Endpoint Discovery
echo -e "${G}[*] Phase 3: Deep Crawling with Katana...${NC}"
cat alive.txt | katana -silent -jc -kf all -d 3 -fs rdn -o urls.txt

# Step 4: Vulnerability Scanning & Exploitation
echo -e "${G}[*] Phase 4: Running Nuclei (Automatic Scan + Exploit Tags)...${NC}"
# Phase 4: Hunting Command
cat urls.txt | nuclei \
    -as -itags exploit,cve,lfi,ssrf,sqli,rce,config \
    -severity critical,high,medium \
    -rl 150 -bs 35 -c 20 \
    -et tags/dos \
    -silent -stream -o "$OUTPUT_FILE" | notify -p discord -bulk

echo -e "${G}[+] Pipeline Finished. Check Discord for potential vulnerabilities.${NC}"
