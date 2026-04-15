# 🎯 Black-Nuclei: The Weaponized Template Vault

This directory is the core intelligence source for the **BlackTrack** pipeline. It merges elite community research with **JakeLo.ai** custom-built templates to ensure maximum coverage during large-scale vulnerability scanning.

## 📂 Vault Structure

* **`DhiyaneshGeek/`**: High-fidelity templates focusing on critical CVEs, misconfigurations, and modern web vulnerabilities.
* **`geeknik/`**: A collection of expert-level templates known for discovering deep-level vulnerabilities and edge-case exploits.
* **`jakelo/`**: 
    * **`newest/`**: This is the "Zero-Day & N-Day" folder. It contains proprietary templates developed by JakeLo.ai for the latest 2026 vulnerabilities.

## 🛠️ Integration Guide

To utilize these templates within your existing workflow, follow these steps:

### 1. Manual Sync (Recommended)
Merge these specialized templates into your local Nuclei directory to keep your environment clean:
```bash
# From the root of BlackTrack repo
cp -r black-nuclei/* ~/nuclei-templates/
```

### 2. Verification
Check if the custom templates are recognized by Nuclei:
```bash
nuclei -tl -t ~/nuclei-templates/jakelo/newest/
```

## ⚡ Usage in BlackTrack
The **BlackTrack** engine is pre-configured to automatically scan all directories within this vault. By pointing the `-t` flag to the root of your templates folder, you leverage the full power of this integrated library.

---

### 💡 The Hunter's Mindset
> "Don't just scan; understand the surface. The best bounties are found where the official templates end and the custom research begins." — **JakeLo.ai**
