# LFS
## Overview
[Linux From Scratch - Version 10.1](https://www.linuxfromscratch.org/lfs/download.html)

# Preparing for the build
Instead of creating partitions on the host machine, a virtual disk will be used instead.
This disk will be manipulated using a loopback device and it will be booted via qemu.

## Creating qemu disk image
```
❯ qemu-img create lfs-target-disk.img 30G
```
### Use the image file as a loopback device
```
❯ sudo losetup -P /dev/loop0 ./lfs-target-disk.img
❯ sudo fdisk -l /dev/loop0
Disk /dev/loop0: 30 GiB, 32212254720 bytes, 62914560 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
```

### Setup partitions
```
❯ sudo fdisk /dev/loop0
```
https://wiki.archlinux.org/title/Fdisk#Create_a_partition_table_and_partitions

MBR partition table, 3 primary partitions:

1. boot partition (200M)
2. swap partition (4G)
3. root partition (25.8G)

```
❯ sudo fdisk -l /dev/loop0
Device       Boot   Start      End  Sectors  Size Id Type
/dev/loop0p1         2048   411647   409600  200M 83 Linux
/dev/loop0p2       411648  8800255  8388608    4G 83 Linux
/dev/loop0p3      8800256 62914559 54114304 25.8G 83 Linux
```

### Setup filesystems
```
❯ sudo mkfs -v -t ext4 /dev/loop0p1
❯ sudo mkswap /dev/loop0p2
❯ sudo mkfs -v -t ext4 /dev/loop0p3
```

### Mounting partitions
#### Root partition
```
❯ export LFS=/mnt/lfs
❯ sudo mkdir -pv $LFS
❯ sudo mount -v -t ext4 /dev/loop0p3 $LFS
```

#### Boot partition
```
❯ sudo mkdir -v $LFS/boot
❯ sudo mount -v -t ext4 /dev/loop0p1 $LFS/boot
```

#### Enable swap partition
```
❯ sudo swapon -v /dev/loop0p2
```

#### Result
```
❯ mount | grep loop0
/dev/loop0p3 on /mnt/lfs type ext4 (rw,relatime)
/dev/loop0p1 on /mnt/lfs/boot type ext4 (rw,relatime)
```

## Preparations
### Packages
```
❯ mkdir -v $LFS/sources
❯ chmod -v a+wt $LFS/sources
❯ wget --input-file=wget-list --continue --directory-prefix=$LFS/sources
❯ cp md5sums $LFS/sources
❯ pushd $LFS/sources
❯ md5sum -c md5sums
❯ popd
```

### Creating the necessary folders

```
❯ sudo su -l root
[sudo] password for ariel:
[root@archlinux ~]#
[root@archlinux ~]# export LFS=/mnt/lfs
[root@archlinux ~]# mkdir -pv $LFS/{bin,etc,lib,sbin,usr,var}
case $(uname -m) in
x86_64) mkdir -pv $LFS/lib64 ;;
esac
mkdir: created directory '/mnt/lfs/bin'
mkdir: created directory '/mnt/lfs/etc'
mkdir: created directory '/mnt/lfs/lib'
mkdir: created directory '/mnt/lfs/sbin'
mkdir: created directory '/mnt/lfs/usr'
mkdir: created directory '/mnt/lfs/var'
mkdir: created directory '/mnt/lfs/lib64'
[root@archlinux ~]# mkdir -pv $LFS/tools
mkdir: created directory '/mnt/lfs/tools'
```

### Adding the lfs user
```
❯ sudo groupadd lfs
❯ sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs
❯ sudo passwd lfs
```

#### Changing ownership

```
❯ sudo chown -v lfs $LFS/{usr,lib,var,etc,bin,sbin,tools}
changed ownership of '/mnt/lfs/usr' from root to lfs
changed ownership of '/mnt/lfs/lib' from root to lfs
changed ownership of '/mnt/lfs/var' from root to lfs
changed ownership of '/mnt/lfs/etc' from root to lfs
changed ownership of '/mnt/lfs/bin' from root to lfs
changed ownership of '/mnt/lfs/sbin' from root to lfs
changed ownership of '/mnt/lfs/tools' from root to lfs

❯ case $(uname -m) in
x86_64) sudo chown -v lfs $LFS/lib64 ;;
esac

changed ownership of '/mnt/lfs/lib64' from root to lfs

❯ sudo chown -v lfs $LFS/sources
changed ownership of '/mnt/lfs/sources' from root to lfs
```

#### Login as lfs
```
❯ su - lfs
Password:
[lfs@archlinux ~]$
```

### Setting up the environment (run as user lfs)
#### .bash_profile
```
cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF
```
#### .bashrc
```
cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
EOF
```

```
source ~/.bash_profile
```

## Booting with qemu
```
❯ qemu-system-x86_64 -enable-kvm -m 256 -hda lfs-target-disk.img
```

# Resources
https://nilisnotnull.blogspot.com/2015/02/installing-lfs-with-qemu.html?m=0
