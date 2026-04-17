# BlackTrack - Large Scale Vulnerability Pipeline

**The Core Recon Engine of JakeLo.ai**

## Overview

BlackTrack is a high-performance, automated reconnaissance and vulnerability scanning pipeline designed for professional bug bounty hunters. This tool is built on the principle of **Information Asymmetry**—providing you with custom intelligence that standard scans miss.

The v6.5 Master Edition focuses on **Direct Execution Speed** and shadow asset discovery, integrating the best of the hacker community (ProjectDiscovery, Geeknik, DhiyaneshDK) along with JakeLo.ai self-custom templates for the latest N-day vulnerabilities.

## Core Features

  * **Direct High-Velocity Scanning**: Removed proxy overhead for maximum execution speed on authorized targets and VPN-backed environments.
  * **Deep Asset Discovery**: Integrates Amass brute-forcing and Subfinder passive gathering for an exhaustive domain map.
  * **Shadow Asset Discovery**: Utilizes TLSX for Certificate Transparency analysis to find hidden SAN domains.
  * **Optimized Crawling**: Deep crawling via Katana with automated static asset filtering to focus on high-value endpoints (APIs, parameters).
  * **Nuclear Nuclei Engine**: High-concurrency scanning using multi-source templates and randomized User-Agents.
  * **Automated Reporting**: Generates a structured Markdown report summarizing assets, critical findings, and manual review targets.

## Installation & Integration

1.  **Clone the repository**

    ```bash
    git clone https://github.com/jakeloai/BlackTrack/
    cd BlackTrack
    ```

2.  **Run Environment Setup**

    ```bash
    chmod +x install.sh
    sudo ./install.sh
    ```

3.  **Merge Custom Templates**
    Move the contents of the `black-nuclei/` directory to your local nuclei folder:

    ```bash
    cp -r black-nuclei/* ~/nuclei-templates/
    ```

4.  **Initialize Engine**

    ```bash
    chmod +x blacktrack.sh
    # Optional: Move to bin for global access
    sudo cp blacktrack.sh /usr/local/bin/blacktrack
    ```

## Execution

```bash
./blacktrack.sh [options]
```

### Options

| Option | Description |
| :--- | :--- |
| -r \<file\> | Root Domain file (Mandatory) |
| -s \<file\> | Subdomain targets (Passive gathering) |
| -a \<file\> | Amass deep brute targets (Active discovery) |
| -w \<file\> | Wordlist for Amass (Default: top1mil) |
| -h | Show help menu |

## Technical Workflow

1.  **Phase 1: Recon & Shadow Discovery**
    Combined approach using Subfinder (Passive), Amass (Brute-force), and TLSX (SAN extraction from SSL/TLS certificates).
2.  **Phase 2: Web Recon & Optimized Crawling**
    httpx-toolkit validates alive hosts. Katana then crawls for endpoints while filtering out noise (images, css, fonts) to isolate high-value URLs.
3.  **Phase 3: Nuclear Nuclei Attack**
    Runs multi-source templates (Official + JakeLo.ai) in Direct Mode with optimized rate limits. Findings are streamed to Discord via Notify.
4.  **Phase 4: BBOT Final Sweep**
    Executes a "kitchen-sink" OSINT scan to ensure no hidden assets or vulnerabilities are left unturned.
5.  **Phase 5: Automated Report Generation**
    Compiles a `BlackTrack_Report.md` detailing the attack surface and critical/high vulnerabilities.

## Setting up Discord Notifications (Notify)

BlackTrack uses `notify` to stream findings directly to your Discord.

1.  **Create Webhook**: Discord Server Settings \> Integrations \> Webhooks.
2.  **Configure File**: `~/.config/notify/provider-config.yaml`
3.  **Configuration Template**:
    ```yaml
    discord:
      - id: "server_id"
        discord_channel_id: "none"
        discord_webhook_url: "YOUR_WEBHOOK_URL"
    ```

## The Hunter's Code: Safety First

In bug bounty hunting, trust is a luxury you cannot afford.

  * **Audit Code**: When gathering templates from other sources, always audit the YAML logic.
  * **Direct Mode Note**: Without proxies, ensure your source IP is whitelisted or you are using a reliable VPN to avoid accidental ISP blacklisting.
  * **Rule**: Always grep for suspicious strings (`child_process`, `execSync`, `Uint8Array`) before running new community templates on your local machine.

-----

### JakeLo.ai Philosophy

"Information is power, but verified information is profit."

Use BlackTrack to automate the tedious work, so you can focus on the manual PoC that leads to the bounty. Stay sharp, stay safe.
