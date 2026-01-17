# ScanSnap iX500 Setup on Ubuntu 24.04 Server

This guide sets up a Fujitsu ScanSnap iX500 scanner on Ubuntu 24.04 Server, making it available as a network scanner (AirScan/eSCL) accessible from macOS, Windows, iOS, and Android devices.

## Hardware Info

- **Scanner:** Fujitsu ScanSnap iX500
- **USB Vendor ID:** 04c5
- **USB Product ID:** 132b
- **SANE Backend:** fujitsu

## Prerequisites

- Ubuntu 24.04 Server with USB port
- ScanSnap iX500 connected via USB
- Network connectivity

---

## Step 1: Install SANE and Dependencies

```bash
sudo apt update
sudo apt install -y \
    sane \
    sane-utils \
    libsane-dev \
    libusb-1.0-0-dev \
    libjpeg-dev \
    libpng-dev \
    avahi-daemon \
    build-essential \
    cmake \
    git
```

## Step 2: Verify Scanner Detection

Check if the scanner is connected via USB:

```bash
lsusb | grep -i fujitsu
```

Expected output should show something like:
```
Bus 00X Device 00Y: ID 04c5:132b Fujitsu, Ltd ScanSnap iX500
```

Check if SANE detects the scanner:

```bash
scanimage -L
```

Expected output:
```
device `fujitsu:ScanSnap iX500:XXXXXX' is a FUJITSU ScanSnap iX500 scanner
```

## Step 3: Configure USB Permissions

Create a udev rule so SANE can access the scanner without root:

```bash
sudo tee /etc/udev/rules.d/55-scansnap-ix500.rules << 'EOF'
# Fujitsu ScanSnap iX500
ATTRS{idVendor}=="04c5", ATTRS{idProduct}=="132b", MODE="0666", GROUP="scanner", ENV{libsane_matched}="yes"
EOF
```

Add the `saned` user to the scanner group and create the group if needed:

```bash
sudo groupadd -f scanner
sudo usermod -aG scanner saned
```

Reload udev rules:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

**Unplug and replug the scanner**, then verify permissions:

```bash
# Find the device
lsusb | grep -i fujitsu

# Check permissions (replace XXX/YYY with actual bus/device numbers)
ls -la /dev/bus/usb/XXX/YYY
```

The device should show mode `0666` or be owned by group `scanner`.

## Step 4: Test SANE Scanning

Test that scanning works:

```bash
# List available options
scanimage --device 'fujitsu' --help

# Do a test scan (outputs to test.png)
scanimage --device 'fujitsu' --format=png --resolution 300 -o test.png
```

If you get "no SANE devices found", try:

```bash
# Run as saned user to verify permissions
sudo -u saned scanimage -L
```

## Step 5: Install AirSane

AirSane publishes SANE scanners via Apple's AirScan (eSCL) protocol.

```bash
cd /tmp
git clone https://github.com/SimulPiscator/AirSane.git
cd AirSane
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo make install
```

## Step 6: Configure AirSane

Create/edit the AirSane configuration:

```bash
sudo tee /etc/default/airsane << 'EOF'
# AirSane configuration

# Network interface to listen on (empty = all interfaces)
INTERFACE=""

# Port to listen on
PORT=8090

# Access log file (empty = no logging)
ACCESS_LOG=""

# Run as this user
USER=saned

# Additional options
# --debug for verbose logging
# --hotplug to detect USB hotplug events
OPTIONS="--hotplug"
EOF
```

## Step 7: Create Systemd Service

```bash
sudo tee /etc/systemd/system/airsane.service << 'EOF'
[Unit]
Description=AirSane Scanner Service
After=network.target avahi-daemon.service
Wants=avahi-daemon.service

[Service]
Type=simple
EnvironmentFile=/etc/default/airsane
ExecStart=/usr/local/bin/airsaned --interface=${INTERFACE} --port=${PORT} --access-log=${ACCESS_LOG} ${OPTIONS}
User=saned
Group=scanner
Restart=on-failure
RestartSec=5

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
```

Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable airsane
sudo systemctl start airsane
sudo systemctl status airsane
```

## Step 8: Configure Avahi (mDNS)

Ensure Avahi is running for network discovery:

```bash
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon
```

## Step 9: Firewall Configuration

If using UFW:

```bash
sudo ufw allow 8090/tcp comment "AirSane scanner"
sudo ufw allow 5353/udp comment "mDNS/Avahi"
```

If using iptables directly:

```bash
sudo iptables -A INPUT -p tcp --dport 8090 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 5353 -j ACCEPT
```

## Step 10: Verify Setup

### Check AirSane web interface

Open in a browser: `http://<server-ip>:8090/`

You should see the scanner listed with a link to its status page.

### Check mDNS advertisement

```bash
avahi-browse -a | grep -i scanner
```

### Test from macOS

1. Open **Image Capture** app
2. The scanner should appear under "Shared" or "Bonjour"
3. Select it and try a scan

### Test from iOS/iPadOS

1. Open any app with print/scan functionality
2. The scanner should appear as an AirScan device

---

## Troubleshooting

### Scanner not detected by SANE

```bash
# Check USB connection
lsusb | grep -i fujitsu

# Check SANE debug output
SANE_DEBUG_FUJITSU=5 scanimage -L

# Check if backend is available
ls /usr/lib/x86_64-linux-gnu/sane/libsane-fujitsu.*
```

### Permission denied errors

```bash
# Verify udev rules are loaded
udevadm info -a -n /dev/bus/usb/XXX/YYY | grep -E "(idVendor|idProduct)"

# Check saned user can access device
sudo -u saned scanimage -L

# Reapply permissions
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### AirSane not starting

```bash
# Check service status
sudo systemctl status airsane

# Check logs
sudo journalctl -u airsane -f

# Run manually for debugging
sudo -u saned /usr/local/bin/airsaned --debug
```

### Scanner not appearing on network

```bash
# Check Avahi is running
sudo systemctl status avahi-daemon

# Check mDNS advertisements
avahi-browse -art

# Check firewall
sudo ufw status
```

### USB 3.0 Issues

The iX500 may have issues with some USB 3.0 ports. If you experience problems:

1. Try a USB 2.0 port instead
2. Or use a USB 2.0 hub between the scanner and USB 3.0 port

---

## Workarounds for Duplex Scanning

AirSane/AirScan may not expose all scanner options (like duplex) to client devices. Here are workarounds for full duplex scanning support.

### Option 1: Command Line on the Server

SSH into your server and scan directly with SANE:

```bash
scanimage --device 'fujitsu' \
  --source 'ADF Duplex' \
  --mode Color \
  --resolution 300 \
  --format=tiff \
  --batch=scan_%03d.tiff
```

Then retrieve the files via SMB, NFS, or scp.

### Option 2: Install scanservjs (Better Web Interface)

scanservjs provides a full web UI with all scanner options including duplex, resolution, color mode, and output format selection.

**Install Docker first (if not already installed):**

```bash
# Add Docker's official GPG key and repository
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
```

**Run scanservjs:**

```bash
sudo docker run -d \
  --name scanservjs \
  --restart unless-stopped \
  -p 8080:8080 \
  --device /dev/bus/usb:/dev/bus/usb \
  sbs20/scanservjs:latest
```

Then open `http://<server-ip>:8080/` for a complete scanning interface.

**Firewall configuration (if needed):**

```bash
sudo ufw allow 8080/tcp comment "scanservjs web interface"
```

**Native installation:** https://github.com/sbs20/scanservjs

---

## Quick Reference Commands

```bash
# Check scanner status
scanimage -L

# Test scan
scanimage --format=png --resolution 300 -o test.png

# Restart AirSane
sudo systemctl restart airsane

# View AirSane logs
sudo journalctl -u airsane -f

# AirSane web interface
http://<server-ip>:8090/
```

---

## Scanner-Specific Settings

The iX500 supports these SANE options:

| Option | Values | Description |
|--------|--------|-------------|
| `--resolution` | 50-600 dpi | Scan resolution |
| `--mode` | Lineart, Gray, Color | Color mode |
| `--source` | ADF Front, ADF Back, ADF Duplex | Paper source |
| `--page-width` | 0-224mm | Page width |
| `--page-height` | 0-876mm | Page height |

Example duplex color scan at 300 DPI:

```bash
scanimage --device 'fujitsu' \
  --source 'ADF Duplex' \
  --mode Color \
  --resolution 300 \
  --format=png \
  --batch=scan_%03d.png
```
