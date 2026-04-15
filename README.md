# BlackBounty
**Hunter : Jake**

BlackBounty is a high-performance, automated reconnaissance and vulnerability scanning pipeline designed for large-scale bug hunting. It leverages a dynamic proxy-rotation system to bypass WAFs and IP-based rate limiting.

---

## 🛠 How It Works

BlackBounty automates a multi-stage workflow protected by a rotating proxy layer:

1.  **Proxy Acquisition**: Pulls 5,000+ fresh HTTP/SOCKS4/SOCKS5 proxies from verified public repositories.
2.  **Live Validation**: Performs a high-speed parallel health check (50 threads) to filter out dead nodes.
3.  **Dynamic ProxyChains**: Generates a custom `proxychains4` configuration on-the-fly using the `dynamic_chain` logic.
4.  **Stealth Recon**:
    * **Subfinder**: Deep subdomain enumeration via `proxychains`.
    * **HTTPX**: Fast active host probing using native proxy-list rotation.
5.  **Targeted Scanning**: Executes `Nuclei` templates across all alive hosts, routing traffic through the validated proxy pool.

---

## 🚀 Installation

Run the installation script to set up all dependencies (Go, Subfinder, HTTPX, Nuclei, Proxychains4):

```bash
chmod +x install.sh
./install.sh
```

---

## 🎯 Usage

Prepare a list of root domains in a text file:

**targets.txt**
```text
example.com
target-app.net
bugbounty-program.org
```

**Start the Hunt:**
```bash
blackbounty targets.txt
```

---

## 📂 Output Structure

All results are organized in the `bounty_output/` directory:

- `raw_proxies.txt`: All gathered proxy nodes.
- `valid_proxies.txt`: Verified working proxies used for the current session.
- `01_subs_raw.txt`: Unique subdomains discovered.
- `02_alive_hosts.txt`: Active web targets.
- `03_vulns.txt`: Final vulnerability report.

---

## ⚠️ Disclaimer
This tool is for educational purposes and authorized Bug Bounty programs only. The hunter (Jake) is not responsible for any misuse or damage caused by this script.

## Quick Start Guide
1.  Place `BlackBounty.sh`, `install.sh`, and your `targets.txt` in the same folder.
2.  Run `sudo ./install.sh`.
3.  Type `blackbounty targets.txt` and watch the automated pipeline execute.

This setup ensures that your identity is masked from the very first subdomain request. Since you are doing large-scale hunting, would you like me to add a **"Resume"** feature to the script so it can pick up where it left off if the connection drops?
