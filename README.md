# idx-linux

run Linux with QEMU/KVM inside Google's IDX workspace


## quick start

1. head to https://idx.google.com and click import repo
2. on import screen, pasted this repo url and check the mobile sdk support
3. the workspace will automatically setup thing for you
4. access via noVNC URL printed on startup
5. follow the [installation guide](./INSTALLATION_GUIDE.md) to install the system (arch)
6. install KDE Plasma or XFCE for a graphical desktop *optional*

## installation guide

see [INSTALLATION_GUIDE.md](./INSTALLATION_GUIDE.md) for complete step-by-step instructions including:
- disk partitioning and formatting
- base system installation
- UEFI bootloader setup
- desktop environment installation (KDE Plasma or XFCE)

## accessing your VM

the startup script automatically creates a public URL via Cloudflared. check the workspace logs for the URL.

## project structure

```
idx-linux/
├── .idx/
│   └── dev.nix           # Nix environment and startup script
├── INSTALLATION_GUIDE.md # complete installation instructions
└── README.md             # this file
```

## related projects

- [idx-windows-gui](https://github.com/kmille36/idx-windows-gui) - Windows 11 QEMU IDX workspace setup
- [idx-macos](https://github.com/imfluxxy/idx-macos) - macOS QEMU IDX workspace setup
- [OSX-KVM](https://github.com/kholia/OSX-KVM) - virtual Hackintosh setup

## troubleshooting

- **QEMU won't start**: check `/tmp/qemu.log`
- **no network**: use `nmtui` or `systemctl restart NetworkManager`
- **low disk space**: the VM disk is 24GB; resize with `qemu-img resize` if needed

## notes

- your workspace is **ONE** time use
- don't try to enter your personal account inside the vm since it's a public cloudflared tunnel
- full installation documentation in [INSTALLATION_GUIDE.md](./INSTALLATION_GUIDE.md)
