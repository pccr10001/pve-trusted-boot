PVE Trusted Boot with TPM and LUKS
===

## Goal
* Install Proxmov VE
* Enforce Secure boot
* Keep kernel and initramfs update automatically
* Seal with TPM to protect kernel, initramfs and kernel cmdline.

## My Environment
* Intel N100
* 8G DDR4
* 128G NVMe SSD
* BIOS Supports TPM 2.0 and Secure Boot

## Boot with Debian Live CD
* Get Debian Bookworm Live DVD from 
    * [https://mirror.twds.com.tw/debian-cd/12.11.0-live/amd64/iso-hybrid/debian-live-12.11.0-amd64-standard.iso](https://mirror.twds.com.tw/debian-cd/12.11.0-live/amd64/iso-hybrid/debian-live-12.11.0-amd64-standard.iso)
* Create bootable USB drive using rufus or others tools.
* Boot Debian USB drive with `EFI` mode.

## Partition
* My SSD is 128G NVMe, locate at `/dev/nvme0n1`
* Partition Table
    * 500M `EFI` `/boot/efi`
    * 500M `Boot` `/boot`
    * 4G Swap
    * 114G LVM for `root` and VMs
* Using `fdisk` to part the disk.

```bash=
root@debian:~# fdisk /dev/nvme0n1

Welcome to fdisk (util-linux 2.38.1).
Changes will remain in memory only, until you decide to write them.
Be careful before using the write command.


Command (m for help): n
Partition number (1-128, default 1):
First sector (2048-250069646, default 2048):
Last sector, +/-sectors or +/-size{K,M,G,T,P} (2048-250069646, default 250068991): +500M

Created a new partition 1 of type 'Linux filesystem' and of size 500 MiB.

Command (m for help): n
Partition number (2-128, default 2):
First sector (1026048-250069646, default 1026048):
Last sector, +/-sectors or +/-size{K,M,G,T,P} (1026048-250069646, default 250068991): +500M

Created a new partition 2 of type 'Linux filesystem' and of size 500 MiB.

Command (m for help): n
Partition number (3-128, default 3):
First sector (2050048-250069646, default 2050048):
Last sector, +/-sectors or +/-size{K,M,G,T,P} (2050048-250069646, default 250068991): +4G

Created a new partition 3 of type 'Linux filesystem' and of size 4 GiB.

Command (m for help): n
Partition number (4-128, default 4):
First sector (10438656-250069646, default 10438656):
Last sector, +/-sectors or +/-size{K,M,G,T,P} (10438656-250069646, default 250068991):

Created a new partition 4 of type 'Linux filesystem' and of size 114.3 GiB.
```

* Then set labels and type for each partitions

```bash=
Command (m for help): t
Partition number (1-4, default 4): 1
Partition type or alias (type L to list all): 1

Changed type of partition 'Linux filesystem' to 'EFI System'.

Command (m for help): t
Partition number (1-4, default 4): 2
Partition type or alias (type L to list all): 4

Changed type of partition 'Linux filesystem' to 'BIOS boot'.

Command (m for help): t
Partition number (1-4, default 4): 3
Partition type or alias (type L to list all): swap

Changed type of partition 'Linux filesystem' to 'Linux swap'.

Command (m for help): t
Partition number (1-4, default 4): 4
Partition type or alias (type L to list all): lvm

Changed type of partition 'Linux filesystem' to 'Linux LVM'.

Command (m for help):
```

* Save changes to disk.

```bash=
Command (m for help): w
The partition table has been altered.
Calling ioctl() to re-read partition table.
Syncing disks.

root@debian:~#
```

### Format partitions
* Install FAT32 tools
    * `apt install dosfstools`
```bash=
root@debian:~# apt install dosfstools
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following NEW packages will be installed:
  dosfstools
0 upgraded, 1 newly installed, 0 to remove and 0 not upgraded.
Need to get 142 kB of archives.
After this operation, 323 kB of additional disk space will be used.
Get:1 http://deb.debian.org/debian bookworm/main amd64 dosfstools amd64 4.2-1 [142 kB]
Fetched 142 kB in 0s (723 kB/s)
Selecting previously unselected package dosfstools.
(Reading database ... 83280 files and directories currently installed.)
Preparing to unpack .../dosfstools_4.2-1_amd64.deb ...
Unpacking dosfstools (4.2-1) ...
Setting up dosfstools (4.2-1) ...
Processing triggers for man-db (2.11.2-2) ...
```

* Format partitions
```bash=
root@debian:~# mkfs.fat -F32 /dev/nvme0n1p1
mkfs.fat 4.2 (2021-01-31)

root@debian:~# mkfs.ext4 /dev/nvme0n1p2
mke2fs 1.47.0 (5-Feb-2023)
Discarding device blocks: done
Creating filesystem with 512000 1k blocks and 128016 inodes
Filesystem UUID: f9abf8f0-5925-4a6d-8e5e-7d0e1aee40a8
Superblock backups stored on blocks:
        8193, 24577, 40961, 57345, 73729, 204801, 221185, 401409

Allocating group tables: done
Writing inode tables: done
Creating journal (8192 blocks): done
Writing superblocks and filesystem accounting information: done

root@debian:~# mkswap /dev/nvme0n1p3
Setting up swapspace version 1, size = 4 GiB (4294963200 bytes)
no label, UUID=69b75414-231a-471c-a6fe-8b948d51ffcd

root@debian:~#
```

## Setup LUKS
* Install related tools
    * `apt install clevis clevis-tpm2 clevis-luks cryptsetup tpm2-tools`

* Create LUKS on `/dev/nvme0n1p4`
    * Please define a password to unlock the partition.
    * `cryptsetup luksFormat /dev/nvme0n1p4`
```bash=
root@debian:~# cryptsetup luksFormat /dev/nvme0n1p4

WARNING!
========
This will overwrite data on /dev/nvme0n1p4 irrevocably.

Are you sure? (Type 'yes' in capital letters): YES
Enter passphrase for /dev/nvme0n1p4:
Verify passphrase:
root@debian:~#
```

* Open encrypted partition and mount it on `cryptroot`
    * `cryptsetup open /dev/nvme0n1p4 cryptroot`
```bash=
root@debian:~# cryptsetup open /dev/nvme0n1p4 cryptroot
Enter passphrase for /dev/nvme0n1p4:
root@debian:~#
```

## Setup LVM
* Install LVM tools
    * `apt -y install lvm2`
* Create PV
    * `pvcreate /dev/mapper/cryptroot`
```bash=
root@debian:~# pvcreate /dev/mapper/cryptroot
  Physical volume "/dev/mapper/cryptroot" successfully created.
```
* Create VG
    * `vgcreate pve /dev/mapper/cryptroot`
```bash=
root@debian:~# vgcreate pve /dev/mapper/cryptroot
  Volume group "pve" successfully created
```
* Create LV
    * I chosed 40G as `root` for PVE
```bash=
root@debian:~# lvcreate -L 40G -n root pve
  Logical volume "root" created.
root@debian:~# lvcreate -l 100%FREE --thinpool data pve
  Thin pool volume with chunk size 64.00 KiB can address at most <15.88 TiB of data.
  Logical volume "data" created.
```
* Format PVE `root`
```bash=
root@debian:~# mkfs.ext4 /dev/pve/root
mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 10485760 4k blocks and 2621440 inodes
Filesystem UUID: 6d9ec1fc-8743-4748-ba20-766541debbbb
Superblock backups stored on blocks:
        32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632, 2654208,
        4096000, 7962624

Allocating group tables: done
Writing inode tables: done
Creating journal (65536 blocks): done
Writing superblocks and filesystem accounting information: done
root@debian:~#
```

## Install Debian
* Mount root for PVE
    * `mount /dev/pve/root /mnt`
* Install `debootstrap`
    * `apt install -y debootstrap`
* Install Debian with debootstrap
    * You can also change mirror for APT.
    * `debootstrap --arch amd64 stable /mnt http://free.nchc.org.tw/debian`
* Mount system directory for `chroot`
```bash=
mount --make-rslave --rbind /proc /mnt/proc
mount --make-rslave --rbind /sys /mnt/sys
mount --make-rslave --rbind /dev /mnt/dev
mount --make-rslave --rbind /run /mnt/run
```
* Chroot to Debian
    * `chroot /mnt`
* Mount `/boot`
    * `mount /dev/nvme0n1p2 /boot`
    * `mkdir /boot/efi`
    * `mount /dev/nvme0n1p1 /boot/efi`
* Update APT sources
```bash=
root@debian:~# cat > /etc/apt/sources.list << EOF
deb http://free.nchc.org.tw/debian/ bookworm main contrib non-free non-free-firmware
deb-src http://free.nchc.org.tw/debian/ bookworm main contrib non-free non-free-firmware

deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware

deb http://free.nchc.org.tw/debian/ bookworm-updates main contrib non-free non-free-firmware
deb-src http://free.nchc.org.tw/debian/ bookworm-updates main contrib non-free non-free-firmware
EOF

root@debian:~# apt update
```
* Update `/etc/fstab`
```
/dev/nvme0n1p2          /boot          ext4    defaults    0      2
/dev/nvme0n1p1          /boot/efi      vfat    defaults    0      1
/dev/mapper/pve-root    /              ext4    defaults    0      1
```
* Add `/etc/crypttab`
    * `echo "cryptroot UUID=$(blkid -o value -s UUID /dev/nvme0n1p4) none luks,discard" > /etc/crypttab`
* Configute timezone
    * `dpkg-reconfigure tzdata`
* Configure Locales
    * `apt install -y locales`
    * `dpkg-reconfigure locales
* Set password for `root`
    * `passwd root`
* Install Kernel
    * Remove Realtek firmware if you don't need it.
    * `apt install -y linux-image-amd64 firmware-linux firmware-realtek`
* Setup Hostname
    * `echo "pvebox2" > /etc/hostname`
* Setup `/etc/hosts`
    * PVE needs to resolve IP with full FQDN hostname, replace following entries and save to `/etc/hosts`
```
127.0.0.1 localhost
{LAN_IP_ADDRESS} {HOSTNAME} {HOSTNAME}.{FQDN}

::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
```

```
# Example

127.0.0.1 localhost
192.168.2.1 pvebox2 pvebox2.example.tld

::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
```
* Install Grub2
    * `apt install -y grub-efi-amd64-signed grub2`
    * `grub-install --target=x86_64-efi --uefi-secure-boot --efi-directory=/boot/efi /dev/nvme0n1`
    * `update-grub`
* Configure network
    * Set DNS server in `/etc/ressolv.conf`
    * Configure network setting in `/etc/network/interfaces`
```
allow-hotplug enp1s0
iface enp1s0 inet static
    address 192.168.2.2
    netmask 255.255.255.0
    gateway 192.168.2.1
```
## Configure LUKS
* Install related tools
    * `apt install clevis-tpm2 clevis-luks clevis cryptsetup clevis-initramfs cryptsetup-initramfs lvm2`
* Bind LUKS to TPM without checking PCR
    * `clevis luks bind -d /dev/nvme0n1p4 tpm2 '{}'`
* Reboot
    * You will see following output in boot logs, LUKS unlock with TPM2 and boot successfully

## Install Proxmox
* Following instruction from Proxmox Wiki 
    * [https://pve.proxmox.com/wiki/Install_Proxmox_VE_on_Debian_12_Bookworm](https://pve.proxmox.com/wiki/Install_Proxmox_VE_on_Debian_12_Bookworm)
* Enable Proxmox APT source
    * `echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list`
    * `apt install -y wget`
    * `wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg`
    * `apt update && apt full-upgrade -y`
* Install Proxmox kernel
    * `apt install proxmox-default-kernel -y`
    * `reboot`
* Install Proxmox
    * `apt install proxmox-ve postfix open-iscsi chrony -y`
* Remove Debian kernel image
    * `apt remove linux-image-amd64 'linux-image-6.1*'`
    * `update-grub`
    * `reboot`
* Add `local-lvm` storage
    * `pvesm add lvmthin local-lvm data`
* Enable Secure boot in BIOS
* Now your system will boot with 

## Enable Trusted Boot for PVE
* Check TPM hash algorithm
    * `tpm2_pcrread`
    * Please check banks in TPM, make sure ID 7,8,9 have values.
    * Check hash algorithm that contains ID 7,8,9, eg. `SHA256`
* Unbind LUKS with TPM
```
root@pvebox2:~# clevis luks unbind -d /dev/nvme0n1p4 -s 1
The unbind operation will wipe a slot. This operation is unrecoverable.
Do you wish to erase LUKS slot 1 on /dev/nvme0n1p4? [ynYN] y
Enter any remaining passphrase:
```
* Bind LUKS with TPM PCR ID 7,8,9
    * `clevis luks bind -d /dev/nvme0n1p4 tpm2 '{"pcr_ids":"7,8,9"}'`
    * You need to input password during boot if you update kernel and initramfs.

## Enable auto-sealing during updating kernel and initramfs
* To make LUKS unlock automatically, we need to unbind and re-bind LUKS with PCR ID 7,8,9
* Create a unlock key in `/root`
    * `dd if=/dev/urandom of=/root/.luks_unlock_key bs=1 count=32`
    * `chmod 400 /root/.luks_unlock_key`
* Add key to LUKS
    * `cryptsetup luksAddKey /dev/nvme0n1p4 /root/.luks_unlock_key`
* Create `/etc/systemd/system/tpm-full-reseal.service` to bind LUKS with TPM during boot
* Create re-bind script `/usr/local/sbin/tpm-full-reseal-post-boot.sh`
* Enable reseal service
    * `chmod 700 /usr/local/sbin/tpm-full-reseal-post-boot.sh`
    * `systemctl enable tpm-full-reseal.service`
* Create initramfs hook `/etc/initramfs/post-update.d/99-tpm-auto-reseal`
* Enable initramfs hook
    * `chmod 700 /etc/initramfs/post-update.d/99-tpm-auto-reseal`
## Testing
* Check LUKS is binded with TPM PCR ID 7,8,9
```
root@pvebox2:~# clevis luks list -d /dev/nvme0n1p4
2: tpm2 '{"hash":"sha256","key":"ecc","pcr_bank":"sha256","pcr_ids":"7,8,9"}'
```
* Update initramfs to check unseal is working
```
root@pvebox2:~# update-initramfs -k all -u
update-initramfs: Generating /boot/initrd.img-6.8.12-11-pve
TPM Hook: initramfs for kernel 6.8.12-11-pve has been updated at /boot/initrd.img-6.8.12-11-pve.
Starting TPM auto-reseal process.
Unbinding existing TPM token from slot 2...
Binding temporary token using PCR 7...
Creating trigger file for post-reboot finalization...
TPM Hook: Successfully prepared system for reboot. A reboot is required to finalize TPM configuration.
Running hook script 'zz-proxmox-boot'..
Re-executing '/etc/kernel/postinst.d/zz-proxmox-boot' in new private mount namespace..
No /etc/kernel/proxmox-boot-uuids found, skipping ESP sync.
System booted in EFI-mode but 'grub-efi-amd64' meta-package not installed!
Install 'grub-efi-amd64' to get updates.
```
