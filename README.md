# 🛡️ BlackBounty
**Hunter : Jake**

**BlackBounty** is an enterprise-grade, automated reconnaissance and vulnerability scanning pipeline. It is specifically engineered for **large-scale bug hunting** where bypassing WAFs, avoiding IP bans, and receiving real-time alerts are critical to success.

---

## ⚙️ How It Works

BlackBounty orchestrates a multi-stage security workflow while maintaining a "Zero-Exposure" profile:

1.  **Passive Recon**: Deep subdomain discovery using `subfinder`.
2.  **Live Probing**: Validates active web servers using `httpx-toolkit` (optimized for Kali Linux).
3.  **Deep Crawling**: Uses `katana` to map endpoints and hidden parameters.
4.  **Universal Scanning Engine**: Runs `Nuclei` with a hybrid logic—combining technology-based auto-scanning (`-as`) with mandatory exploit tag enforcement.
5.  **Smart Alerting**: Filters noisy reconnaissance data and only pings your **Discord** when actual vulnerabilities are found.

---

## 🚀 Installation & Setup

### 1. Clone and Prepare
```bash
chmod +x install.sh blackbounty.sh
sudo ./install.sh
```

### 2. Configure Discord Real-Time Alerts (CRITICAL)
BlackBounty uses ProjectDiscovery's `notify` tool to send findings. You must configure your Discord Webhook properly for the script to alert you.

**Step A: Get your Discord Webhook URL**
* Go to **Discord** > **Server Settings** > **Integrations** > **Webhooks**.
* Create a **New Webhook**, name it "BlackBounty", and **Copy Webhook URL**.

**Step B: Configure the Provider File**
Create or edit the configuration file at `~/.config/notify/provider-config.yaml`:

```bash
mkdir -p ~/.config/notify/
nano ~/.config/notify/provider-config.yaml
```

**Step C: Paste the following config** (Replace the URL with yours):
```yaml
discord:
  - id: "discord"
    discord_webhook_url: "https://discord.com/api/webhooks/your_webhook_id/your_webhook_token"
```

**Step D: Test the Connection**
```bash
echo "BlackBounty Notify Test" | notify -p discord
```
*If your Discord "pings", you are ready to hunt.*

---

## 🎯 Usage

To start a new hunting session, provide a file containing your target root domains:

**targets.txt**
```text
example.com
target-site.net
```

**Run the command:**
```bash
./blackbounty.sh targets.txt
```

---

## 🛠 Vulnerability Logic (The Nuclei Phase)

BlackBounty doesn't just "run tools"; it uses a **Universal Scanning Command** designed to hit both modern and legacy systems (like `vulnweb` targets):

```bash
cat urls.txt | nuclei \
    -as -itags cve,exploit,lfi,ssrf,sqli,rce,config \
    -severity critical,high,medium \
    -silent -stream -bs 50 -c 25 \
    -o results.txt | notify -p discord -bulk
```

* **`-as`**: Auto-detects tech stacks to save time.
* **`-itags`**: Forcefully runs high-value tags (SQLi, XSS, RCE) even if tech detection fails.
* **`-bulk`**: Bundles multiple findings into one Discord message to prevent API rate-limits.
* **`-o results.txt`**: Local backup in case Discord fails.



---

## 📂 Output Files

| File | Description |
| :--- | :--- |
| `subs.txt` | All unique subdomains discovered. |
| `alive.txt` | Hosts responding to HTTP/HTTPS. |
| `urls.txt` | Deep endpoints crawled by Katana. |
| `results.txt` | **The Loot.** Final vulnerability report (Critical/High/Medium). |

---

## ⚠️ Safety & Ethics
* **Ethics**: Only use this tool on domains authorized by Bug Bounty programs.
* **Noise**: Be aware that `-bs 50` and `-c 25` are fast. If you get blocked, lower these numbers.
* **Privacy**: Never share your `provider-config.yaml` as it contains your private Discord tokens.

**Good hunting, Jake.**
