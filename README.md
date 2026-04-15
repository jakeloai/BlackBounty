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
   Move the contents of the `black-nuclei/` directory to your local nuclei folder:
   ```bash
   cp -r black-nuclei/* ~/nuclei-templates/
   ```
3. **Keep it Sharp:**
   Always ensure your official templates are updated before a hunt:
   ```bash
   nuclei -ut -silent
   ```
4. **Setup Engine:**
   ```bash
   chmod +x blacktrack.sh
   # Optional: Move to bin for global access
   sudo cp blacktrack.sh /usr/local/bin/blacktrack
   ```

## 📢 Setting up Discord Notifications (Notify)
BlackTrack uses `notify` to stream findings directly to your Discord.

### Step 1: Create a Discord Webhook
1. Open your Discord server settings > **Integrations** > **Webhooks**.
2. Click **New Webhook**, select your channel, and **Copy Webhook URL**.

### Step 2: Configure the Provider File
Create the config file:
```bash
mkdir -p ~/.config/notify/
nano ~/.config/notify/provider-config.yaml
```
Paste this minimalist configuration:
```yaml
discord:
  - id: "server_id"
    discord_channel_id: "none"
    discord_webhook_url: "webhook_url_MUST_HAVE"
```

### Step 3: Fast Ping Test
Verify your setup with a single command:
```bash
echo "BlackTrack Connection Test: Success" | notify -p discord
```

## ⚠️ The Hunter's Code: Safety First
If you are seeing this tool, congrats. You are now part of an elite circle. However, in bug bounty hunting, trust is a luxury you cannot afford.

* **Caution**: When gathering templates from other hackers, **always** audit the code.
* **Hackback Protection**: Malicious actors often hide **"hackback"** code (obfuscated JS or malicious shell commands) within innocent-looking YAML templates. 
* **Rule**: Always grep for suspicious strings (`child_process`, `execSync`, `Uint8Array`) before running new community templates on your local machine. Stay safe.

## ⚡ Execution
```bash
./blacktrack.sh targets.txt
```

## 🏗️ Technical Workflow
1. **Passive Discovery**: Exhaustive subdomain gathering via multiple sources.
2. **Active Probing**: Validating alive hosts and filtering out noise (404/403).
3. **Endpoint Extraction**: Deep crawling with Katana to find hidden parameters and API endpoints.
4. **Targeted Scanning**: Running multi-source templates (Official + Community + JakeLo.ai) with OOB support.

---

### 💡 JakeLo.ai Philosophy
"Information is power, but verified information is profit." 

Use **BlackTrack** to automate the tedious work, so you can focus on the manual PoC that leads to the bounty. Stay sharp, stay safe, and happy hunting.
