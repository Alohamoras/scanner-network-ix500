# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a documentation repository containing setup instructions for a Fujitsu ScanSnap iX500 scanner on Ubuntu 24.04 Server. It configures the scanner as a network AirScan/eSCL device accessible from macOS, Windows, iOS, and Android.

**Files:**
- `instructions.md` - Step-by-step manual setup guide
- `install.sh` - Automated installation script

## Architecture

The documented system has these layers:
- **Hardware**: Fujitsu ScanSnap iX500 (USB 04c5:132b)
- **Driver**: SANE with fujitsu backend
- **Services**: AirSane daemon (scanner publishing) + Avahi daemon (mDNS discovery)
- **Optional**: scanservjs Docker container (full-featured web UI with duplex support)
- **Protocol**: Apple AirScan (eSCL)

## Key Reference Commands

```bash
# Check scanner detection
scanimage -L

# Test scan
scanimage --device 'fujitsu' --format=png --resolution 300 -o test.png

# Duplex batch scan
scanimage --device 'fujitsu' --source 'ADF Duplex' --mode Color --resolution 300 --format=tiff --batch=scan_%03d.tiff

# Service management
sudo systemctl status airsane
sudo systemctl restart airsane
sudo journalctl -u airsane -f

# Debug SANE
SANE_DEBUG_FUJITSU=5 scanimage -L

# Check mDNS
avahi-browse -a | grep -i scanner
```

## Key Configuration Files

- `/etc/udev/rules.d/55-scansnap-ix500.rules` - USB device permissions
- `/etc/default/airsane` - AirSane configuration
- `/etc/systemd/system/airsane.service` - systemd service unit

## Web Interfaces

- AirSane: `http://<server-ip>:8090/`
- scanservjs (optional): `http://<server-ip>:8080/`
