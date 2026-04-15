# README.md

# 🛡️ BlackTrack - Large Scale Vulnerability Pipeline
**The Core Recon Engine of JakeLo.ai**

## 🚀 Overview
**BlackTrack** is a high-performance, automated reconnaissance and vulnerability scanning pipeline designed for professional bug bounty hunters. This tool is built on the principle of **Information Asymmetry**—providing you with custom intelligence that standard scans miss.

It integrates the best of the hacker community (**ProjectDiscovery**, **Geeknik**, **DhiyaneshDK**) along with **JakeLo.ai self-custom templates** for the latest N-day vulnerabilities.

## 🛠️ Installation & Integration
To use this engine, you must manually sync the templates provided in this repo to your local Nuclei templates directory.

1. **Clone the repository:**
   ```bash
   git clone https://github.com/jakeloai/BlackTrack/
   cd BlackTrack
   ```
2. **Merge Templates:**
   Move the contents of the `black-nuclei/` directory to your local nuclei folder (typically `~/nuclei-templates/`):
   ```bash
   # Merging specialized templates into your local environment
   cp -r black-nuclei/* ~/nuclei-templates/
   ```
3. **Setup Engine:**
   Ensure `blacktrack.sh` is executable:
   ```bash
   chmod +x blacktrack.sh
   ```

## ⚠️ The Hunter's Code: Safety First
If you are seeing this tool, congrats. You are now part of an elite circle. However, in bug bounty hunting, trust is a luxury you cannot afford.

* **Caution**: When gathering templates from other hackers, **always** audit the code.
* **Hackback Protection**: Malicious actors often hide **"hackback"** code (obfuscated JS or malicious shell commands) within innocent-looking YAML templates. 
* **Rule**: Always grep for suspicious strings (`wasm`, `Uint8Array`, or local file execution) before running new community templates on your local machine. Stay safe.

## ⚡ Execution
```bash
./blacktrack.sh targets.txt
```

## 🏗️ Technical Workflow
1. **Passive Discovery**: Exhaustive subdomain gathering via multiple sources.
2. **Active Probing**: Validating alive hosts and filtering out noise (404/403).
3. **Endpoint Extraction**: Deep crawling with Katana to find hidden parameters and API endpoints.
4. **Targeted Scanning**: Running multi-source templates with OOB (Interactsh) support for maximum impact.

---

### 💡 JakeLo.ai Philosophy
"Information is power, but verified information is profit." 

Use **BlackTrack** to automate the tedious work, so you can focus on the manual PoC that leads to the bounty. Stay sharp, stay safe, and happy hunting.
