# ScanSnap iX500 Network Scanner Setup

> Because Fujitsu decided their $400 scanner should only work with their proprietary software that they abandoned in 2020. Cool. Cool cool cool.

Turn your "obsolete" ScanSnap iX500 into a network scanner that actually works with everything — macOS, Windows, iOS, Android. No ScanSnap Home. No cloud accounts. No nonsense.

## What This Does

Takes a perfectly good scanner that Fujitsu left for dead and resurrects it as an AirScan device using open source software. Your iPhone will think it's a fancy new network scanner. It's not. It's your old iX500 running on a Linux box in a closet somewhere. But hey, it works.

## Requirements

- Ubuntu 24.04 Server (or mass-produce your own kernel modules, I'm not your dad)
- Fujitsu ScanSnap iX500
- A USB cable (remember those?)
- 10 minutes of your time

## Quick Start

```bash
# For the "I read documentation" crowd
cat instructions.md

# For the "just make it work" crowd
chmod +x install.sh && ./install.sh
```

## The Catch

AirScan is great and all, but it doesn't expose every scanner option to your devices. Want duplex scanning from your iPhone? Too bad. Apple's scanning interface is... minimalist.

**Workarounds included:**
- SSH in and scan like it's 2005 (it works, don't judge)
- Run scanservjs in Docker for a proper web UI with all the bells and whistles

## Architecture

```
┌─────────────┐     USB      ┌─────────────┐    Network    ┌─────────────┐
│  iX500      │─────────────▶│  Ubuntu     │──────────────▶│  Your       │
│  (the hero) │              │  + AirSane  │   AirScan     │  Devices    │
└─────────────┘              └─────────────┘               └─────────────┘
                                   │
                                   ▼
                             ┌─────────────┐
                             │  scanservjs │ (optional, for duplex)
                             │  :8080      │
                             └─────────────┘
```

## Web Interfaces

| Service | URL | Purpose |
|---------|-----|---------|
| AirSane | `http://<server>:8090/` | Basic status, scanner info |
| scanservjs | `http://<server>:8080/` | Full scanning UI (if you set it up) |

## FAQ

**Q: Will this work with other ScanSnap models?**
A: Maybe. The iX500 uses the `fujitsu` SANE backend. If your model does too, you might get lucky. YMMV.

**Q: Why not just buy a new scanner?**
A: The iX500 is genuinely excellent hardware. 25 pages per minute, duplex, reliable document feeder. Fujitsu just sucks at software. This fixes that.

**Q: Is this legal?**
A: Yes. You own the hardware. SANE is open source. We're just using things as intended.

**Q: My scanner isn't detected. Help?**
A: Unplug it. Plug it back in. Check `instructions.md` troubleshooting section. Consider percussive maintenance as a last resort.

## License

Do whatever you want with this. It's instructions for connecting a scanner to a computer. We're not curing cancer here.

---

*Made with mild frustration and open source software.*
