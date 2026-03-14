# blockdag-operator-toolkit

**Pre-Forge Collection · by Apu Saha**

These are the tools I built before I knew how to build properly.

No architecture diagrams. No clean modules. No refactoring.
Just real scripts, written under real pressure, solving real problems.

This is where I learned Linux, Docker, networking, and automation —
not in a course, but by fixing things that were broken.

---

## The Context

These scripts were built for a real community of BlockDAG node operators.

Real people. Real machines. Real problems.

When someone in the group had a broken node — sync stuck, Docker refusing to
start, permissions broken, RocksDB corrupted after a crash — I tried to fix it.
If I could reproduce the problem and solve it, I wrote a script so it wouldn't
happen again. Then I redeployed it back to the community.

Some scripts didn't make it. If something wasn't working well enough, I deleted
it rather than leave broken tools in people's hands. What's in this folder is
what survived.

The installers were built specifically for people who had never touched Linux
before. Complete beginners. The setup is fully interactive — it talks you through
every step, explains what it's doing, and won't proceed without your confirmation.
The goal was that anyone in the community could run a node, regardless of their
technical background.

All of this was built in good faith, for a project that turned out to be a scam.
We didn't know that yet. The community was real, the problems were real, and the
work was real — even if the project wasn't.

When everything collapsed, I kept the scripts. Not for the project — but because
I'd learned something, and that didn't disappear when the scam was exposed.

---

## What's In Here

24 tools across 7 categories. Every single one exists because something broke
and I had to fix it.

```
blockdag-operator-toolkit/
├── 01-installation-and-self-healing/
├── 02-system-optimization/
├── 03-node-monitoring-and-diagnostics/
├── 04-docker-and-permissions/
├── 05-backup-and-recovery/
├── 06-database-tools/
└── 07-web-tools/
```

---

## The Tools

### 📦 01 · Installation & Self-Healing

| File | What it does |
|---|---|
| `Wolverine.sh` | Multi-node installer v7.3. If the GitHub download link breaks, it detects it, asks for a new URL, validates the files, then **rewrites its own source code** with the new link. Also auto-detects ports, isolates nodes, and generates management scripts. |
| `installer-v7.2.sh` | The generation before Wolverine. Downloads clean reference files first, then builds node directories from those. |
| `Linux-Node-v6-SMART.sh` | v6 smart installer — earlier and simpler than Wolverine. Previous versions were deleted. This is the oldest one that survived. |
| `Patch-v6.sh` | Hotfix. v6 had a bug where stopping Node 1 stopped *all* nodes. This finds the affected file and fixes exactly that one line. |
| `Restart manager.sh` | Restarts multiple nodes in sequence. Discord notifications on completion. Supports cron scheduling. |

---

### ⚡ 02 · System Optimization

| File | What it does |
|---|---|
| `bdg_optimizer_v1.1.sh` | Tunes Linux for node workloads — memory, disk scheduler, CPU governor, file descriptor limits. Backs up all original settings first. v1.1 fixed a bug where systemd silently reset file limits back to 1024. |
| `bdg_reverse_optimizer_v1.1.sh` | Undoes everything the optimizer did. Full reversal, setting by setting. |
| `Flush.sh` | Removes all BlockDAG files and Docker remnants from the system. For starting completely fresh. |
| `Optimization-guides.md` | Written reference for verifying the optimizer worked. Commands to check every setting. |

---

### 📡 03 · Node Monitoring & Diagnostics

| File | What it does |
|---|---|
| `ETA.sh` | Queries block height twice, calculates sync speed, tells you how long until the node catches up. Multi-node aware. |
| `Latency-Peer.sh` | Analyses all connected peers — geographic location, TCP latency, health score. Helped diagnose slow sync caused by poor peer distribution. |
| `Port-Forwarding.sh` | Checks if required ports are open and reachable externally. Walks through fixing it if they're not. |

---

### 🐋 04 · Docker & Permissions

| File | What it does |
|---|---|
| `Official-Docker-Installation.sh` | Installs Docker from the official repository — not the Ubuntu default which is often outdated. |
| `Remove-Old-Docker.sh` | Removes conflicting legacy Docker packages before a clean install. |
| `Fix-Permissions.sh` | Fixes the issue where every Docker command requires `sudo`. Repairs group membership. |
| `check-permissions.sh` | Diagnostic only. Reports current Docker permission state without changing anything. |

---

### 💾 05 · Backup & Recovery

| File | What it does |
|---|---|
| `4folder-bkup.sh` | Targets 4 specific folders buried deep inside node root directories and backs them up with configurable retention — automatically removes the oldest backup when the limit is hit. |
| `bkup-need-work.sh` | A backup script I started and never finished. Kept exactly as-is. Not everything ships. |
| `JumpStart.sh` | For community members falling behind on node sync. Someone who was fully synced would upload their 4 node folders to a shared drive. Those who were behind downloaded them, then ran this script to safely place those files exactly where they belong inside the node directory. Jump straight to today's sync instead of waiting days. |
| `Restore.sh` | Restores from backup with real-time rsync progress. Handles internal drives, external drives, and network storage. Rewritten multiple times after earlier versions failed silently. |
| `Simple-Copy.sh` | Interactive folder copy that preserves hidden files, symlinks, and permissions — things `cp -r` quietly drops. |

---

### 🗄️ 06 · Database Tools

| File | What it does |
|---|---|
| `SST-RockDB.sh` | Scans RocksDB .sst files for corruption after a hard crash. Identifies the faulty files, removes them from the node root, and isolates them in a separate folder — keeping the bad files away from where they can cause damage. |

---

### 🌐 07 · Web Tools

| File | What it does |
|---|---|
| `crypto_tracker.html` | Open in any browser — no install, no server. Tracks transactions across multiple wallets and chains (ETH, TRX, DOGE, BNB, SOL, XRP, BTC and more). Exports to Excel. Built during a fraud investigation to track funds moving across rotating addresses in real time. Later became the seed for WalletDNA. |
| `README_CryptoTracker.pdf` | Usage guide for the tracker. |

---

## Why These Are Kept Raw

These scripts are unmodified — no refactoring, no cleanup, no rewriting.

They are a historical record. Changing them would make them dishonest.

---

## How This Fits My Portfolio

```
P-01  MultiSig Treasury    ← trust without verification costs millions
P-02  OmniNode             ← infrastructure that runs itself
P-03  TX Monitor           ← knowing what's failing before it's too late
P-04  WalletDNA            ← behavioural patterns behind financial loss
P-05  This collection      ← where it all started
```

The bash scripts became ChainOps.
The presale tracker became WalletDNA.
Everything here was a lesson that compounded.

---

## Usage

Most scripts run on Ubuntu/Debian Linux and require Docker.

```bash
git clone https://github.com/apu-saha-990/blockdag-operator-toolkit
cd blockdag-operator-toolkit
chmod +x **/*.sh
```

Web tracker — open `07-web-tools/crypto_tracker.html` directly in a browser.

> Provided as-is, unmodified, for historical accuracy.
> Test before running on live systems.

Everything here is from before I even knew what architecture was — the operator mindset that still guides how I build

---

**Apu Saha** — Self-taught infrastructure engineer.
