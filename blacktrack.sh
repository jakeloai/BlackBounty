#!/bin/bash

# --- Help Menu ---
show_help() {
    echo "Usage: ./blacktrack.sh [options]"
    echo ""
    echo "Options:"
    echo "  -d <file>    Domain file (Static single targets like example.com, dev.example.com. Skips Subfinder)"
    echo "  -w <file>    Wildcard file (Patterns like *.example.com, dev.*.example.com. Runs Subfinder)"
    echo "  -h, --help   Show this help message"
    echo ""
    echo "Examples:"
    echo "  1. Domain only:    ./blacktrack.sh -d domains.txt"
    echo "  2. Wildcard only:  ./blacktrack.sh -w wildcards.txt"
    echo "  3. Both targets:   ./blacktrack.sh -d domains.txt -w wildcards.txt"
    exit 0
}

# --- Argument Parsing ---
DOMAIN_FILE=""
WILDCARD_FILE=""

while getopts "d:w:h" opt; do
    case $opt in
        d) DOMAIN_FILE=$OPTARG ;;
        w) WILDCARD_FILE=$OPTARG ;;
        h) show_help ;;
        *) show_help ;;
    esac
done

# --- Variable Initialization ---
DATE=$(date +%Y%m%d_%H%M)
OUTPUT_DIR="recon_$DATE"
OUTPUT_FILE="$OUTPUT_DIR/nuclei_results.txt"
FINAL_TARGETS="$OUTPUT_DIR/all_targets.txt"
TEMP_DOMAINS="$OUTPUT_DIR/domains_to_scan.txt"
TEMP_REGEX="$OUTPUT_DIR/grep_patterns.txt"

# --- Validation ---
if [[ -z "$DOMAIN_FILE" && -z "$WILDCARD_FILE" ]]; then
    echo "[!] Error: You must provide at least -d (Domain) or -w (Wildcard) file."
    show_help
fi

# Check if files exist
[[ -n "$DOMAIN_FILE" && ! -f "$DOMAIN_FILE" ]] && { echo "[!] Error: Domain file '$DOMAIN_FILE' not found."; exit 1; }
[[ -n "$WILDCARD_FILE" && ! -f "$WILDCARD_FILE" ]] && { echo "[!] Error: Wildcard file '$WILDCARD_FILE' not found."; exit 1; }

# Dependency Check
tools=("subfinder" "httpx-toolkit" "katana" "nuclei" "notify")
for tool in "${tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        echo "[!] Error: Dependency '$tool' is not installed."
        exit 1
    fi
done

mkdir -p "$OUTPUT_DIR"

echo "[+] Starting Pipeline"
[[ -n "$DOMAIN_FILE" ]] && echo "[+] Domain File: $DOMAIN_FILE"
[[ -n "$WILDCARD_FILE" ]] && echo "[+] Wildcard File: $WILDCARD_FILE"

# --- Phase 1: Wildcard Pattern Processing ---
if [[ -n "$WILDCARD_FILE" ]]; then
    echo "[*] Phase 1: Processing Wildcard targets..."
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == *"\*"* ]]; then
            # Extract base domain for Subfinder (e.g., dev.*.example.com -> example.com)
            base_domain=$(echo "$line" | sed 's/.*\*//; s/^\.//')
            echo "$base_domain" >> "$TEMP_DOMAINS"
            
            # Convert wildcard to Regex for Grep
            regex=$(echo "$line" | sed 's/\./\\./g; s/\*/[a-zA-Z0-9.-]+/g' | sed 's/^/^/; s/$/$/')
            echo "$regex" >> "$TEMP_REGEX"
        else
            # If a normal domain accidentally slips into the wildcard file
            echo "$line" >> "$TEMP_DOMAINS"
            regex=$(echo "$line" | sed 's/\./\\./g' | sed 's/^/^/; s/$/$/')
            echo "$regex" >> "$TEMP_REGEX"
        fi
    done < "$WILDCARD_FILE"

    # Run Subfinder on extracted base domains
    sort -u "$TEMP_DOMAINS" -o "$TEMP_DOMAINS"
    echo "[*] Running Subfinder on base domains..."
    subfinder -dL "$TEMP_DOMAINS" -silent -o "$OUTPUT_DIR/raw_subs.txt"

    # Apply Grep Filter based on user wildcard patterns
    echo "[*] Filtering results based on wildcard patterns..."
    grep -E -f "$TEMP_REGEX" "$OUTPUT_DIR/raw_subs.txt" > "$OUTPUT_DIR/filtered_subs.txt"
fi

# --- Phase 2: Final Target Merging ---
echo "[*] Merging Domain and Wildcard results..."
if [[ -n "$DOMAIN_FILE" && -n "$WILDCARD_FILE" ]]; then
    cat "$DOMAIN_FILE" "$OUTPUT_DIR/filtered_subs.txt" | sort -u > "$FINAL_TARGETS"
elif [[ -n "$DOMAIN_FILE" ]]; then
    cp "$DOMAIN_FILE" "$FINAL_TARGETS"
else
    cp "$OUTPUT_DIR/filtered_subs.txt" "$FINAL_TARGETS"
fi

if [ ! -s "$FINAL_TARGETS" ]; then
    echo "[!] Warning: No targets to process. Exiting."
    exit 0
fi

# --- Phase 3: Live Host Probing ---
echo "[*] Phase 3: Identifying Alive Hosts (Httpx)..."
cat "$FINAL_TARGETS" | httpx-toolkit -silent -fc 404 -o "$OUTPUT_DIR/alive.txt"

if [ ! -s "$OUTPUT_DIR/alive.txt" ]; then
    echo "[!] Warning: No alive hosts found."
    exit 0
fi

# --- Phase 4: Endpoint Discovery (Katana) ---
echo "[*] Phase 4: Deep Crawling (Katana)..."
cat "$OUTPUT_DIR/alive.txt" | katana -silent -jc -kf all -d 3 -fs rdn -o "$OUTPUT_DIR/urls.txt"

# --- Phase 5: Vulnerability Scanning (Nuclei) ---
echo "[*] Phase 5: Running Nuclei Scan..."
if [ -s "$OUTPUT_DIR/urls.txt" ]; then
    cat "$OUTPUT_DIR/urls.txt" | nuclei \
        -t ~/nuclei-templates \
        -as \
        -severity low,medium,high,critical \
        -rl 100 -bs 25 -c 15 \
        -et tags/dos \
        -silent -stream -o "$OUTPUT_FILE" | notify -p discord -bulk
else
    echo "[!] No URLs found to scan."
fi

echo "[+] Pipeline Finished. Results saved to: $OUTPUT_FILE"
