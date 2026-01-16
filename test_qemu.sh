#!/bin/bash
# Test script for QEMU - allows testing without re-running dev.nix

set -e

# =========================
# Paths
# =========================
PROJECT_DIR="$HOME/idx-linux"
VM_DIR="$PROJECT_DIR/qemu"
RAW_DISK="$VM_DIR/archlinux.qcow2"
ARCH_ISO="$VM_DIR/archlinux-x86_64.iso"
OVMF_DIR="$VM_DIR/ovmf"
OVMF_CODE="$OVMF_DIR/OVMF_CODE.fd"
OVMF_VARS="$OVMF_DIR/OVMF_VARS.fd"

# =========================
# Verify required files exist
# =========================
echo "checking for required files..."
if [ ! -f "$OVMF_CODE" ]; then
  echo "❌ missing: $OVMF_CODE"
  exit 1
fi

if [ ! -f "$OVMF_VARS" ]; then
  echo "❌ missing: $OVMF_VARS"
  exit 1
fi

if [ ! -f "$RAW_DISK" ]; then
  echo "❌ missing: $RAW_DISK"
  exit 1
fi

if [ ! -f "$ARCH_ISO" ]; then
  echo "❌ missing: $ARCH_ISO"
  exit 1
fi

echo "✓ all files found"

# =========================
# Kill any existing QEMU processes
# =========================
echo "checking for existing QEMU processes..."
if pgrep -x "qemu-system-x86_64" > /dev/null; then
  echo "killing existing QEMU processes..."
  pkill -f qemu-system-x86_64 || true
  sleep 2
fi

# =========================
# Start QEMU (KVM + UEFI + Linux)
# =========================
echo "starting QEMU with Arch Linux..."
nohup qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp 4,cores=4 \
  -M q35 \
  -m 4096 \
  -device usb-ehci,id=ehci \
  -device usb-tablet \
  -device virtio-balloon-pci \
  -device virtio-serial-pci \
  -device virtio-rng-pci \
  -device ich9-ahci,id=sata \
  -smbios type=2 \
  -device qxl-vga,vram_size=536870912 \
  -net nic,netdev=n0,model=virtio-net-pci \
  -netdev user,id=n0,hostfwd=tcp::2222-:22 \
  -boot d \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
  -drive if=pflash,format=raw,file="$OVMF_VARS" \
  -drive id=main,file="$RAW_DISK",format=qcow2,if=none \
  -device ide-hd,bus=sata.0,drive=main \
  -cdrom "$ARCH_ISO" \
  -vnc :0 \
  -display none \
  -monitor none \
  > /tmp/qemu.log 2>&1 &

QEMU_PID=$!
echo "QEMU PID: $QEMU_PID"

# Give QEMU time to start and check for immediate errors
sleep 2
if ! kill -0 $QEMU_PID 2>/dev/null; then
  echo "❌ QEMU failed to start. Check /tmp/qemu.log"
  cat /tmp/qemu.log
  exit 1
fi

echo "✓ QEMU started successfully"
echo ""
echo "waiting for cloudflared tunnel..."
sleep 5

if grep -q "trycloudflare.com" /tmp/cloudflared.log; then
  URL=$(grep -o "https://[a-z0-9.-]*trycloudflare.com" /tmp/cloudflared.log | head -n1)
  echo "========================================="
  echo " 🌍 Arch Linux QEMU + noVNC ready:"
  echo "     $URL/vnc.html"
  echo "========================================="
else
  echo "❌ Cloudflared tunnel failed"
fi

echo ""
echo "to stop QEMU, run: pkill -f qemu-system-x86_64"
