#!/bin/bash
#
# ScanSnap iX500 Network Scanner Setup Script
# Sets up a Fujitsu ScanSnap iX500 as a network AirScan/eSCL scanner on Ubuntu 24.04
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    error "Do not run this script as root. It will use sudo when needed."
fi

# Check for Ubuntu
if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
    warn "This script is designed for Ubuntu. Proceed with caution on other distributions."
fi

echo "========================================"
echo "ScanSnap iX500 Network Scanner Setup"
echo "========================================"
echo

# Step 1: Install SANE and dependencies
info "Installing SANE and dependencies..."
sudo apt update
sudo apt install -y \
    sane \
    sane-utils \
    libsane-dev \
    libusb-1.0-0-dev \
    libjpeg-dev \
    libpng-dev \
    avahi-daemon \
    avahi-utils \
    libavahi-client-dev \
    build-essential \
    cmake \
    git

# Step 2: Check for scanner
info "Checking for ScanSnap iX500..."
if lsusb | grep -q "04c5:132b"; then
    info "Scanner found via USB"
else
    warn "Scanner not detected. Make sure it's connected and powered on."
    warn "Continuing with setup anyway..."
fi

# Step 3: Configure USB permissions
info "Configuring USB permissions..."
sudo tee /etc/udev/rules.d/55-scansnap-ix500.rules > /dev/null << 'EOF'
# Fujitsu ScanSnap iX500
ATTRS{idVendor}=="04c5", ATTRS{idProduct}=="132b", MODE="0666", GROUP="scanner", ENV{libsane_matched}="yes"
EOF

# Create scanner group and add saned user
sudo groupadd -f scanner
sudo usermod -aG scanner saned 2>/dev/null || true

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Step 4: Build and install AirSane
info "Building AirSane from source..."
AIRSANE_DIR=$(mktemp -d)
cd "$AIRSANE_DIR"
git clone https://github.com/SimulPiscator/AirSane.git
cd AirSane
mkdir build && cd build
cmake ..
make -j$(nproc)

info "Installing AirSane..."
sudo make install

# Clean up build directory
cd /
rm -rf "$AIRSANE_DIR"

# Step 5: Configure AirSane (if not already configured by make install)
if [[ -f /etc/default/airsane ]]; then
    info "AirSane configuration already exists"
else
    info "Creating AirSane configuration..."
    sudo tee /etc/default/airsane > /dev/null << 'EOF'
INTERFACE=*
LISTEN_PORT=8090
ACCESS_LOG=
HOTPLUG=true
RELOAD_DELAY=1
MDNS_ANNOUNCE=true
ANNOUNCE_SECURE=false
ANNOUNCE_BASE_URL=
UNIX_SOCKET=
WEB_INTERFACE=true
RESET_OPTION=true
DISCLOSE_VERSION=true
LOCAL_SCANNERS_ONLY=false
RANDOM_PATHS=false
COMPATIBLE_PATH=true
OPTIONS_FILE=/etc/airsane/options.conf
ACCESS_FILE=/etc/airsane/access.conf
IGNORE_LIST=/etc/airsane/ignore.conf
EOF
fi

# Step 6: Enable and start services
info "Enabling and starting services..."
sudo systemctl daemon-reload
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon
sudo systemctl enable airsaned
sudo systemctl start airsaned

# Step 7: Configure firewall (if UFW is available)
if command -v ufw &> /dev/null; then
    info "Configuring firewall rules..."
    sudo ufw allow 8090/tcp comment "AirSane scanner" 2>/dev/null || true
    sudo ufw allow 5353/udp comment "mDNS/Avahi" 2>/dev/null || true
fi

# Step 8: Verify setup
echo
info "Verifying setup..."
sleep 5  # Give services time to start

# Check SANE detection
echo
if scanimage -L 2>/dev/null | grep -q "fujitsu"; then
    info "SANE detects the scanner"
else
    warn "SANE does not detect the scanner yet. Try unplugging and replugging it."
fi

# Check AirSane service
if systemctl is-active --quiet airsaned; then
    info "AirSane service is running"
else
    warn "AirSane service is not running. Check: sudo journalctl -u airsaned"
fi

# Check mDNS advertisement
if avahi-browse -t _uscan._tcp 2>/dev/null | grep -q "ScanSnap"; then
    info "Scanner is being advertised via mDNS"
else
    warn "mDNS advertisement not detected yet. It may take a moment."
fi

# Get IP address
IP_ADDR=$(hostname -I | awk '{print $1}')

echo
echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo
echo "Web interface: http://${IP_ADDR}:8090/"
echo "mDNS name:     $(hostname).local"
echo
echo "The scanner should now appear on:"
echo "  - macOS: Image Capture app"
echo "  - iOS/iPadOS: Apps with scan support"
echo "  - Windows 10/11: Settings > Printers & scanners"
echo
echo "Quick commands:"
echo "  scanimage -L                      # Check scanner detection"
echo "  sudo systemctl status airsaned    # Check service status"
echo "  sudo journalctl -u airsaned -f    # View logs"
echo
