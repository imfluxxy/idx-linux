{ pkgs, ... }: {
  channel = "stable-24.11";

  packages = [
    pkgs.qemu
    pkgs.htop
    pkgs.cloudflared
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.wget
    pkgs.git
    pkgs.python3
  ];

  idx.workspace.onStart = {
    linux = ''
      set -e

      # =========================
      # One-time cleanup
      # =========================
      if [ ! -f /home/user/.cleanup_done ]; then
        rm -rf /home/user/.gradle/* /home/user/.emu/* || true
        find /home/user -mindepth 1 -maxdepth 1 \
          ! -name 'idx-linux' \
          ! -name '.cleanup_done' \
          ! -name '.*' \
          -exec rm -rf {} + || true
        touch /home/user/.cleanup_done
      fi

      # =========================
      # Paths
      # =========================
      PROJECT_DIR="$HOME/idx-linux"
      VM_DIR="$PROJECT_DIR/qemu"
      RAW_DISK="$VM_DIR/archlinux.qcow2"
      ARCH_ISO="$VM_DIR/archlinux-x86_64.iso"
      NOVNC_DIR="$PROJECT_DIR/noVNC"
      OVMF_DIR="$VM_DIR/ovmf"
      OVMF_CODE="$OVMF_DIR/OVMF_CODE.fd"
      OVMF_VARS="$OVMF_DIR/OVMF_VARS.fd"

      mkdir -p "$PROJECT_DIR"
      mkdir -p "$OVMF_DIR"
      mkdir -p "$VM_DIR"

      # =========================
      # Download OVMF firmware if missing
      # =========================
      if [ ! -f "$OVMF_CODE" ]; then
        echo "Downloading OVMF_CODE.fd from idx-linux-dependencies..."
        wget -O "$OVMF_CODE" \
          "https://github.com/imfluxxy/idx-linux-dependencies/raw/refs/heads/main/OVMF_CODE.fd"
      else
        echo "OVMF_CODE.fd already exists, skipping download."
      fi

      if [ ! -f "$OVMF_VARS" ]; then
        echo "Downloading OVMF_VARS.fd..."
        wget -O "$OVMF_VARS" \
          https://qemu.weilnetz.de/test/ovmf/usr/share/OVMF/OVMF_VARS.fd
      else
        echo "OVMF_VARS.fd already exists, skipping download."
      fi

      # =========================
      # Download Arch Linux ISO if missing
      # =========================
      if [ ! -f "$ARCH_ISO" ]; then
        echo "Downloading Arch Linux ISO..."
        wget -O "$ARCH_ISO" \
          "https://fastly.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso"
      else
        echo "Arch Linux ISO already exists, skipping download."
      fi

      # =========================
      # Clone noVNC if missing
      # =========================
      if [ ! -d "$NOVNC_DIR/.git" ]; then
        echo "Cloning noVNC..."
        mkdir -p "$NOVNC_DIR"
        git clone https://github.com/novnc/noVNC.git "$NOVNC_DIR"
      else
        echo "noVNC already exists, skipping clone."
      fi

      # =========================
      # Create QCOW2 disk if missing
      # =========================
      if [ ! -f "$RAW_DISK" ]; then
        echo "Creating QCOW2 disk (24GB)..."
        qemu-img create -f qcow2 "$RAW_DISK" 24G
      else
        echo "QCOW2 disk already exists, skipping creation."
      fi

      # =========================
      # Start QEMU (KVM + UEFI + Linux)
      # =========================
      echo "Starting QEMU with Arch Linux..."
      nohup qemu-system-x86_64 \
        -enable-kvm \
        -cpu host \
        -smp 4,cores=4 \
        -M q35 \
        -m 4096 \
        -device usb-tablet \
        -device virtio-balloon-pci \
        -device virtio-serial-pci \
        -device virtio-rng-pci \
        -device ich9-ahci,id=sata \
        -smbios type=2 \
        -device qxl-vga,vram_size=512M \
        -net nic,netdev=n0,model=virtio-net-pci \
        -netdev user,id=n0,hostfwd=tcp::2222-:22 \
        -boot d \
        -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
        -drive if=pflash,format=raw,file="$OVMF_VARS" \
        -drive file="$RAW_DISK",format=qcow2,if=ide,bus=sata.0 \
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

      # =========================
      # Start noVNC on port 8888
      # =========================
      echo "Starting noVNC..."
      nohup "$NOVNC_DIR/utils/novnc_proxy" \
        --vnc 127.0.0.1:5900 \
        --listen 8888 \
        > /tmp/novnc.log 2>&1 &

      # =========================
      # Start Cloudflared tunnel
      # =========================
      echo "Starting Cloudflared tunnel..."
      nohup cloudflared tunnel \
        --no-autoupdate \
        --url http://localhost:8888 \
        > /tmp/cloudflared.log 2>&1 &

      sleep 10

      if grep -q "trycloudflare.com" /tmp/cloudflared.log; then
        URL=$(grep -o "https://[a-z0-9.-]*trycloudflare.com" /tmp/cloudflared.log | head -n1)
        echo "========================================="
        echo " 🌍 Arch Linux QEMU + noVNC ready:"
        echo "     $URL/vnc.html"
        echo "     $URL/vnc.html" > "$PROJECT_DIR/noVNC-URL.txt"
        echo "========================================="
      else
        echo "❌ Cloudflared tunnel failed, but QEMU is running"
        echo "You can access noVNC at: http://localhost:8888/vnc.html"
      fi

      # =========================
      # Keep workspace alive
      # =========================
      elapsed=0
      while true; do
        echo "Time elapsed: $elapsed min"
        ((elapsed++))
        sleep 60
      done
    '';
  };

  idx.previews = {
    enable = true;
    previews = {
      archlinux = {
        manager = "web";
        command = [
          "bash" "-lc"
          "echo 'noVNC running on port 8888'"
        ];
      };
      terminal = {
        manager = "web";
        command = [ "bash" ];
      };
    };
  };
}
