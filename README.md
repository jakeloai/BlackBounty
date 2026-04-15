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
