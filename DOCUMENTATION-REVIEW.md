# Homelab Documentation Review: Gaps & Mismatches

**Reviewed against:** `homelab-documentation.md`  
**Actual production access:** `ryzen` → **192.168.1.213** (ubuntu-production), user `adeeladmin`  
**Review date:** 2026-01-22

---

## 1. Critical: Host / Infrastructure Mismatch

| Item | Documentation | Actual (from SSH) |
|------|---------------|-------------------|
| **Production host** | moonstone-temp @ **192.168.1.200** | **ubuntu-production** @ **192.168.1.213** (ryzen) |
| **VM / IP** | VM 100, Ubuntu-Server @ **10.10.10.2** | You SSH directly to **192.168.1.213** (bare metal or different topology) |
| **Hostname** | moonstone-temp | ubuntu-production |

**Implications:**

- The doc describes **moonstone** (192.168.1.200) and **VM 100** (10.10.10.2). Your `~/.ssh/config` and terminal show **ryzen** (192.168.1.213) as “Ryzen Production Server” and **ubuntu-production**.
- **Missing from doc:** Any mention of **ryzen**, **192.168.1.213**, or **ubuntu-production**.
- **Unclear:** Whether moonstone/VM 100 still exist, were replaced by ryzen, or coexist. The doc does not explain the relationship.

**Recommendation:** Either (a) update the doc to document **ryzen/ubuntu-production** as the primary production host and clarify how it relates to moonstone, or (b) explicitly state that the doc describes a different environment (e.g. lab vs production).

---

## 2. Network Architecture

- **Doc:** Gateway 192.168.1.1 → Proxmox 192.168.1.200 → VM 10.10.10.2.
- **Actual:** You reach 192.168.1.213 directly. No doc mention of 192.168.1.213, ubuntu-production, or ryzen in the topology.
- **Missing:** Placement of **192.168.1.213** in the network (same LAN as moonstone? different VLAN? same Proxmox host?).

---

## 3. Hardware & Topology

- **Doc:** Physical host = moonstone-temp; Ubuntu runs in **VM 100** on Proxmox.
- **Actual:** ubuntu-production at 192.168.1.213 could be bare metal, a different VM, or different Proxmox host.
- **Missing:**
  - Whether **ryzen/ubuntu-production** is bare metal or a VM; if VM, which host and which VM ID.
  - Hardware specs for the **ryzen** machine (CPU, RAM, disk).
  - Clear distinction between “moonstone” and “ryzen” roles (e.g. lab vs production).

---

## 4. Services & Config Paths

The doc assumes everything runs on the **10.10.10.2** VM. If production is **ryzen** (192.168.1.213), these may differ:

- **Paths:** `/var/www/...`, `~/docker`, `~/backups`, `~/scripts`, `~/logs` — doc says they exist but doesn’t state **which host** they’re on.
- **Docker:** Doc references `~/docker` and `docker-compose`. No mention of whether ryzen uses the same layout or different compose files.
- **Backup script:** `~/backup_to_drive.sh` and cron — no confirmation that this runs on **ryzen** or that paths match.

**Missing:** Explicit “this runs on moonstone” vs “this runs on ryzen” for each service and path.

---

## 5. Security Configuration

- **Doc:** SSH key-only, no password; UFW “deny all except LAN & tunnel.”
- **Actual:** You SSH to ryzen with **password** (based on terminal); BatchMode/publickey fails.
- **Missing / conflicting:**
  - Doc says “SSH: Key-based auth only (password disabled)” — but you use password to **ryzen**.
  - No note that **ryzen** may have different SSH/auth policy than the documented host.
  - No UFW or firewall details for **192.168.1.213**.

---

## 6. Cloudflare & DNS

- **Doc:** Cloudflare Tunnel; domains like home.funadventure.ae, deploy.funadventure.ae, status.funadventure.ae, n8n.funadventure.ae.
- **Missing:**
  - Which host(s) the tunnel runs on (moonstone VM vs ryzen).
  - How `TUNNEL_TOKEN` / tunnel config is split across hosts if both exist.
  - DNS records and which services point to which IP (192.168.1.200, 10.10.10.2, or 192.168.1.213).

---

## 7. Backup & Operational Details

- **Doc:** Backup script, cron at 03:00, Google Drive, retention, recovery commands.
- **Missing:**
  - Whether the backup script runs on **ryzen** or only on the moonstone VM.
  - Actual cron entries (user vs root) for the documented user.
  - Location and format of `~/logs/backup_drive.log` and whether it’s on the same host you SSH into.

---

## 8. External VPS (82.112.234.8)

- **Actual:** `~/.ssh/config` defines **vps** (82.112.234.8).
- **Doc:** No mention of this VPS or how it relates to the homelab (e.g. offsite backups, staging, etc.).

**Missing:** Short section on external VPS: role, and how it interacts with moonstone/ryzen.

---

## 9. Other Typical Gaps

- **Software versions:** Doc has some (e.g. MariaDB 10.11.13, PostgreSQL 16, PHP 8.3) but not for Nginx, Redis, Gunicorn, Docker, Proxmox (except “9.1.1”). No versions for **ryzen** stack.
- **Cloudflare:** No tunnel ID, config snippet, or which zones/domains use the tunnel.
- **Secrets:** `.env` mentioned; no list of **all** required env vars per service (e.g. n8n, Grafana, Cloudflared).
- **Docker:** No full `docker-compose` example or compose file paths for each environment.
- **Monitoring:** Prometheus scrape config, retention, and alerting (if any) not documented.
- **Updates:** “274 updates” / “131 security” mentioned in the Ubuntu MOTD on **ryzen** — no doc mention of update policy or maintenance window for that host.

---

## 10. How to Verify “Actual” vs Doc

Because SSH to **ryzen** uses password auth, configs couldn’t be pulled automatically. Use this flow:

1. **Copy the capture script to the server:**
   ```bash
   scp /Users/adeelrehman/Desktop/Testing/capture-server-config.sh ryzen:
   ```
2. **SSH in and run it:**
   ```bash
   ssh ryzen
   bash ~/capture-server-config.sh
   ```
3. **Fetch the report:**
   ```bash
   scp ryzen:~/actual-config-report.txt /Users/adeelrehman/Desktop/Testing/
   ```
4. **Compare** `actual-config-report.txt` with `homelab-documentation.md` (paths, services, ports, cron, firewall, Docker, nginx sites).

**Optional:** Add a “Documentation verification” section to the homelab doc that points to this script and the report path, and run it after major changes.

---

## Summary: What’s Missing or Lacking

| Category | What’s missing or wrong |
|----------|--------------------------|
| **Host identity** | ryzen, 192.168.1.213, ubuntu-production not documented; unclear vs moonstone/VM 100 |
| **Network** | 192.168.1.213 not in topology; relation to 192.168.1.200 / 10.10.10.2 unclear |
| **Hardware** | No ryzen hardware specs; unclear if bare metal or VM |
| **Security** | SSH password vs key-only mismatch for ryzen; no UFW details for 192.168.1.213 |
| **Services** | Which host runs what; docker-compose paths and layout for ryzen |
| **Backup** | Which host runs backups; actual cron not documented |
| **External** | VPS 82.112.234.8 and its role not documented |
| **Operational** | Software versions, env vars, Prometheus/alerting, update policy incomplete |

**Suggested next steps:**

1. **Resolve host scope:** Decide whether the doc is for moonstone, ryzen, or both, and update the overview and network sections accordingly.
2. **Run** `capture-server-config.sh` on **ryzen**, then update the doc to match actual paths, services, and firewall.
3. **Align security:** Either enforce key-only SSH on ryzen and document it, or document that ryzen still uses password auth and why.
4. **Add short sections** for: ryzen/ubuntu-production, external VPS, and “Documentation verification” (script + report).
