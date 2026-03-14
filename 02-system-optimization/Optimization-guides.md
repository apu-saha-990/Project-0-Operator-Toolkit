# 📊 BlockDAG Node Monitoring & Verification Guide

**Made By: ArtX for BlockDAG Investors Group**  
**Version: 1.0**

This guide shows you how to monitor your optimized Linux system and verify that all performance improvements are working correctly.

---

## 🎯 Table of Contents

1. [Quick Verification Commands](#quick-verification-commands)
2. [Real-Time Monitoring Tools](#real-time-monitoring-tools)
3. [Performance Benchmarking](#performance-benchmarking)
4. [System Health Checks](#system-health-checks)
5. [Troubleshooting](#troubleshooting)

---

## ✅ Quick Verification Commands

These commands verify that the optimizer script worked correctly.

### **Check Swappiness (Memory Optimization)**
```bash
cat /proc/sys/vm/swappiness
```
**Expected:** `1` (for 16GB+ RAM) or `10` (for 8-16GB RAM)  
**Default was:** `60`  
**What it means:** Lower = Linux uses RAM more, swap less = faster performance

---

### **Check I/O Scheduler (Disk Optimization)**
```bash
# For NVMe drives:
cat /sys/block/nvme0n1/queue/scheduler

# For SSD/HDD drives:
cat /sys/block/sda/queue/scheduler
```
**Expected:** `[none]` for NVMe or `[mq-deadline]` for SSD/HDD (brackets show active)  
**What it means:** Optimized for your storage type = faster disk reads/writes

---

### **Check CPU Governor (CPU Optimization)**
```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```
**Expected:** `performance`  
**Default was:** `powersave` or `ondemand`  
**What it means:** CPU runs at maximum frequency = faster processing

---

### **Check TCP Congestion Control (Network Optimization)**
```bash
sysctl net.ipv4.tcp_congestion_control
```
**Expected:** `bbr`  
**Default was:** `cubic`  
**What it means:** Google's BBR algorithm = 20-30% faster network throughput

---

### **Check File Limits (Connection Optimization)**
```bash
ulimit -n
```
**Expected:** `65536`  
**Default was:** `1024`  
**What it means:** Your node can handle 64x more simultaneous connections

**If showing 1024:** Check hard limit first:
```bash
ulimit -Hn
```
If hard limit is 65536 or higher, you can manually set it:
```bash
ulimit -n 65536
```

---

### **Check All Settings at Once**
```bash
echo "=== OPTIMIZATION STATUS ==="
echo "Swappiness: $(cat /proc/sys/vm/swappiness)"
echo "I/O Scheduler (NVMe): $(cat /sys/block/nvme0n1/queue/scheduler 2>/dev/null || echo 'N/A')"
echo "I/O Scheduler (SSD): $(cat /sys/block/sda/queue/scheduler 2>/dev/null || echo 'N/A')"
echo "CPU Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'N/A')"
echo "TCP Congestion: $(sysctl -n net.ipv4.tcp_congestion_control)"
echo "File Limit (soft): $(ulimit -Sn)"
echo "File Limit (hard): $(ulimit -Hn)"
```

---

## 🖥️ Real-Time Monitoring Tools

These tools were installed by the optimizer script.

### **htop - CPU & RAM Monitor**
```bash
htop
```

**What to look for:**
- **CPU Usage:** Should show all cores being utilized
- **CPU Frequency:** Should show max frequency (e.g., 3.5GHz) not fluctuating
- **Memory:** Swap usage should be very low (0-50MB even under load)
- **Load Average:** Shows system load over 1, 5, 15 minutes

**Useful htop shortcuts:**
- `F2` → Setup → Display options
- `F5` → Tree view (show process hierarchy)
- `F6` → Sort by (CPU, Memory, etc.)
- `F9` → Kill a process
- `F10` or `q` → Quit

---

### **iotop - Disk I/O Monitor**
```bash
sudo iotop
```

**What to look for:**
- **DISK READ:** MB/s being read from disk
- **DISK WRITE:** MB/s being written to disk
- **Top processes:** Which programs are using disk most

**Useful iotop shortcuts:**
- `o` → Only show processes doing I/O
- `a` → Accumulated I/O instead of bandwidth
- `q` → Quit

**When to use:**
- During blockchain sync to see disk performance
- When system feels slow to identify disk bottlenecks

---

### **nethogs - Network Monitor**
```bash
sudo nethogs
```

**What to look for:**
- **SENT:** Upload speed per process (KB/s or MB/s)
- **RECEIVED:** Download speed per process
- **Which process:** See if your BlockDAG node is using network

**Useful nethogs shortcuts:**
- `m` → Change display mode (KB/s, MB/s, etc.)
- `r` → Sort by received
- `s` → Sort by sent
- `q` → Quit

**When to use:**
- Check if your node is syncing properly
- Identify which process is using bandwidth
- Monitor P2P connections

---

### **free - Memory Status**
```bash
free -h
```

**Output explanation:**
```
              total        used        free      shared  buff/cache   available
Mem:           15Gi       2.5Gi       8.2Gi       150Mi       4.8Gi        12Gi
Swap:         2.0Gi          0B       2.0Gi
```

**What each column means:**
- **total:** Total RAM/Swap installed
- **used:** Currently used by programs
- **free:** Completely unused
- **buff/cache:** Used for caching (GOOD - makes system faster)
- **available:** Actually available for new programs (includes buff/cache)
- **Swap used:** Should be very low (0-50MB) = optimization working!

---

### **df - Disk Space**
```bash
df -h
```

**What to look for:**
- Your blockchain storage partition
- Should have at least 500GB free for BlockDAG growth
- **Warning if >80% full:** Time to add storage

---

## 📈 Performance Benchmarking

Compare performance before and after optimization.

### **CPU Benchmark**
```bash
time echo "scale=5000; a(1)*4" | bc -l
```

**What it does:** Calculates Pi to 5000 digits  
**Expected:** Completes faster after optimization  
**Example results:**
- Before: `real 0m15.234s`
- After: `real 0m12.891s` (15-20% faster)

---

### **Disk Write Speed Test**
```bash
# Write 1GB test file
sync; dd if=/dev/zero of=/tmp/test_write bs=1M count=1024 oflag=direct; sync

# Cleanup
rm /tmp/test_write
```

**What to look for:**
- **MB/s** or **GB/s** speed reported at end
- NVMe: Should see 1500-3500 MB/s (after optimization: +25-40%)
- SSD: Should see 400-550 MB/s (after optimization: +15-25%)
- HDD: Should see 80-150 MB/s (after optimization: +10-15%)

---

### **Disk Read Speed Test**
```bash
# Create test file first (1GB)
dd if=/dev/zero of=/tmp/test_read bs=1M count=1024

# Clear cache
sudo sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

# Read test
dd if=/tmp/test_read of=/dev/null bs=1M

# Cleanup
rm /tmp/test_read
```

**What to look for:** Similar speeds to write test

---

### **Network Latency Test**
```bash
# Install if not present
sudo apt install iputils-ping -y

# Test to Google DNS
ping -c 10 8.8.8.8
```

**What to look for:**
- **avg time:** Should be lower after BBR optimization
- **0% packet loss:** No dropped packets

---

### **Network Speed Test**
```bash
# Install speedtest
sudo apt install speedtest-cli -y

# Run test
speedtest-cli
```

**What to look for:**
- **Download:** Your ISP speed (shouldn't change much)
- **Upload:** Your ISP speed (shouldn't change much)
- **Ping/Latency:** Should be 5-15% lower after BBR

---

## 🏥 System Health Checks

Regular checks to ensure system is running optimally.

### **Check System Load**
```bash
uptime
```

**Output example:**
```
12:45:32 up 5 days,  3:21,  1 user,  load average: 0.52, 0.58, 0.59
```

**Load average explanation:**
- Three numbers: 1min, 5min, 15min averages
- **Good:** Below number of CPU cores (e.g., 4-core = load under 4.0)
- **High:** Above CPU cores = system overloaded
- **Optimal for node:** 0.5 - 2.0 on a 4-core system

---

### **Check Failed Services**
```bash
systemctl --failed
```

**Expected:** No failed services (should be empty)  
**If services failed:** Investigate with `systemctl status <service-name>`

---

### **Check Disk Health (For SSD/NVMe)**
```bash
# Install smartmontools
sudo apt install smartmontools -y

# Check NVMe health
sudo smartctl -a /dev/nvme0n1

# Check SSD health
sudo smartctl -a /dev/sda
```

**What to look for:**
- **SMART overall-health:** Should say "PASSED"
- **Percentage Used:** SSD/NVMe wear indicator (under 80% is good)
- **Reallocated Sectors:** Should be 0 or very low

---

### **Check Temperature**
```bash
# Install sensors
sudo apt install lm-sensors -y
sudo sensors-detect --auto

# Check temps
sensors
```

**Safe temperatures:**
- **CPU:** Under 80°C normal, under 90°C under load
- **NVMe:** Under 70°C optimal, up to 85°C acceptable
- **Warning:** Above 90°C = thermal throttling = slower performance

---

### **Check Memory Leaks**
```bash
# Show top memory users
ps aux --sort=-%mem | head -n 10
```

**What to look for:**
- No process using >50% RAM continuously
- No steadily increasing memory usage over time

---

## 🔧 Troubleshooting

Common issues and solutions.

### **Issue: Swap is being used heavily**
```bash
# Check swap usage
free -h | grep Swap

# If swap is >100MB used, check what's using it:
for file in /proc/*/status ; do awk '/VmSwap|Name/{printf $2 " " $3}END{ print ""}' $file; done | sort -k 2 -n -r | head -20
```

**Solution:** Increase RAM or reduce running services

---

### **Issue: High load average**
```bash
# Find what's causing high load
top
# Press '1' to see per-core usage
# Press 'P' to sort by CPU
```

**Solution:** Identify and optimize/stop the high-CPU process

---

### **Issue: Disk 100% busy**
```bash
sudo iotop -o
```

**Solution:** Wait for sync to complete, or identify rogue process

---

### **Issue: Network slow**
```bash
# Check if BBR is active
sysctl net.ipv4.tcp_congestion_control

# Check network errors
ip -s link
```

**Solution:** 
- If not BBR: Re-run optimizer script
- If errors: Check cable, router, ISP

---

### **Issue: File limit still 1024**
```bash
# Check limits configuration
cat /etc/security/limits.conf | grep nofile

# Check PAM configuration
grep pam_limits /etc/pam.d/common-session

# Check SystemD limits
systemctl show user@$(id -u).service | grep LimitNOFILE
```

**Solution:** 
- If SystemD shows `LimitNOFILESoft=1024`: SystemD is overriding
- Re-run updated optimizer script (v1.1+) which fixes SystemD limits

---

## 📊 Creating Your Own Monitoring Dashboard

### **Simple Status Script**
Create a file `~/check_system.sh`:

```bash
#!/bin/bash

echo "=========================================="
echo "  BLOCKDAG NODE SYSTEM STATUS"
echo "=========================================="
echo ""
echo "📊 OPTIMIZATIONS:"
echo "  Swappiness: $(cat /proc/sys/vm/swappiness)"
echo "  CPU Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'N/A')"
echo "  TCP Control: $(sysctl -n net.ipv4.tcp_congestion_control)"
echo "  File Limits: $(ulimit -n)"
echo ""
echo "💾 MEMORY:"
free -h | grep -E "Mem|Swap"
echo ""
echo "💿 DISK SPACE:"
df -h / | tail -n 1
echo ""
echo "🌡️ SYSTEM LOAD:"
uptime
echo ""
echo "=========================================="
```

Make it executable:
```bash
chmod +x ~/check_system.sh
```

Run anytime:
```bash
~/check_system.sh
```

---

## 🎯 Key Performance Indicators (KPIs)

Monitor these regularly:

| Metric | Good | Warning | Critical |
|--------|------|---------|----------|
| **Swap Usage** | <50MB | 50-500MB | >500MB |
| **CPU Load** | <50% | 50-80% | >80% |
| **Disk Free** | >500GB | 200-500GB | <200GB |
| **RAM Free** | >2GB | 1-2GB | <1GB |
| **CPU Temp** | <70°C | 70-85°C | >85°C |
| **NVMe Temp** | <60°C | 60-75°C | >75°C |

---

## 📝 Daily Monitoring Routine

### **Quick 30-Second Check:**
```bash
~/check_system.sh
```

### **Weekly Deep Check:**
```bash
# System health
uptime
free -h
df -h
sensors

# Service status
systemctl --failed

# Disk health
sudo smartctl -H /dev/nvme0n1  # or /dev/sda
```

### **Monthly Benchmark:**
```bash
# Run disk speed test
sync; dd if=/dev/zero of=/tmp/test bs=1M count=1024 oflag=direct; sync
rm /tmp/test

# Check trend - is performance degrading?
```

---

## 🆘 Getting Help

If you notice performance issues:

1. **Run the quick check script** above
2. **Check the KPIs table** - what's in warning/critical?
3. **Share these outputs** in BlockDAG community:
   - `~/check_system.sh` output
   - `htop` screenshot
   - `sudo iotop` if disk-related
   - `sudo nethogs` if network-related

---

## 📚 Additional Resources

### **Learn More About Commands:**
```bash
man htop      # htop manual
man iotop     # iotop manual
man free      # memory manual
man df        # disk space manual
```

### **Online Resources:**
- **htop explained:** https://www.redhat.com/sysadmin/htop
- **Understanding load average:** https://www.brendangregg.com/blog/2017-08-08/linux-load-averages.html
- **Linux performance tools:** https://www.brendangregg.com/linuxperf.html

---

**Made with ❤️ by ArtX for the BlockDAG Community**

*Version 1.0 - December 2025*
