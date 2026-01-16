# idx-linux: arch linux installation guide on qemu

this repository provides an automated setup for running **arch linux** with qemu/kvm in an idx workspace.

## quick start

wait for the script to download all the needed dependencies before you begin. this guide is specifically for arch linux, so don't try using it with other linux distributions.

## installation guide

### option 1: the manual way (a bit challenging)

#### step 1: initial boot with arch linux iso

1. wait for qemu to boot from the arch linux iso
2. you should see the arch linux boot menu
3. select "boot arch linux (x86_64)" to enter the live environment

#### step 2: network configuration (optional)

the network is already pre-configured, but you might want to verify it's working:

```bash
ping archlinux.org
```

if you don't have a connection, try using nmtui:
```bash
nmtui
```

#### step 3: partition and format your disk

1. first, let's see what disks are available:
```bash
lsblk
```

2. your main virtual disk should be `/dev/vda`. let's partition it:
```bash
cfdisk /dev/vda
```

**here's a recommended partition layout:**
- `/dev/vda1` - 512mb (efi system, type efi)
- `/dev/vda2` - remaining space (linux filesystem, type linux)

select "write" and confirm with `yes`.

#### step 4: format the partitions

```bash
mkfs.fat -F 32 /dev/vda1
mkfs.ext4 /dev/vda2
```

#### step 5: mount and install the base system

```bash
mount /dev/vda2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/vda1 /mnt/boot/efi

pacstrap /mnt base linux linux-firmware
```

#### step 6: generate fstab and enter the new system

```bash
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
```

#### step 7: configure your system basics

**set your timezone:**
```bash
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
```

**set up language:**
```bash
# edit /etc/locale.gen and uncomment en_US.UTF-8 UTF-8
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

# set your language
echo "LANG=en_US.UTF-8" > /etc/locale.conf
```

**set your hostname:**
```bash
echo "archlinux" > /etc/hostname

cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   archlinux.localdomain archlinux
EOF
```

#### step 8: set up the bootloader

```bash
pacman -S efibootmgr
bootctl install

# create a boot entry
cat > /boot/efi/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=/dev/vda2 rw
EOF

# set up the loader configuration
cat > /boot/efi/loader/loader.conf << EOF
default arch
timeout 3
editor  no
EOF
```

#### step 9: install what you need & set up networking

```bash
pacman -S networkmanager openssh sudo vim git base-devel
systemctl enable NetworkManager
systemctl enable sshd
```

#### step 10: create a user account

```bash
# set your root password
passwd

# create a new user
useradd -m -G wheel -s /bin/bash archuser
passwd archuser

# let wheel group use sudo
echo "%wheel ALL=(ALL:ALL) ALL" | EDITOR=tee visudo /etc/sudoers.d/wheel
```

#### step 11: finish up and reboot

```bash
exit
umount -R /mnt
reboot
```

### option 2: the easy way

this method is much simpler and lets you use a helper tool to guide you through setup. just run:
```bash
archinstall
```

and follow the prompts to set things up.

your system will reboot from the hard drive. if it tries to boot the iso again, you can edit the qemu configuration or just wait for it to boot from disk.

---

## installing a desktop environment

once you've rebooted into your fresh arch linux system, you can add a nice desktop environment to use instead of the command line.

### option 1: kde plasma (lightweight)

install a minimal kde plasma setup:
```bash
sudo pacman -S plasma-desktop plasma-nm plasma-pa sddm \
    konsole dolphin kcalc spectacle ark
sudo systemctl enable sddm
```

then reboot:
```bash
sudo reboot
```

### option 2: xfce (lightweight)

install xfce:
```bash
sudo pacman -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
sudo systemctl enable lightdm
```

then reboot:
```bash
sudo reboot
```

### switch between desktop environments

if you install both, you can choose which one to use when you log in. just edit `/etc/lightdm/lightdm.conf`:
```bash
sudo vim /etc/lightdm/lightdm.conf
```

and change the session setting to pick your preferred environment.

---

## want to learn more?

- [arch linux installation guide](https://wiki.archlinux.org/title/Installation_guide)
- [qemu documentation](https://www.qemu.org/documentation/)
- [kde plasma on arch](https://wiki.archlinux.org/title/KDE)
- [xfce on arch](https://wiki.archlinux.org/title/Xfce)
