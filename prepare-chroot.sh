#!/bin/bash
if [ -z "$LFS" ]; then
	export LFS=/mnt/lfs
fi

mkdir -pv $LFS
# Setup a loopback device so the image file is accessible as a block device
losetup -P /dev/loop0 ./lfs-target-disk.img
mount -v -t ext4 /dev/loop0p3 $LFS
mkdir -v $LFS/boot
mount -v -t ext4 /dev/loop0p1 $LFS/boot
sudo swapon -v /dev/loop0p2

# Setup mount points
mount -v --bind /dev $LFS/dev
mount -v --bind /dev/pts $LFS/dev/pts
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount -vt tmpfs tmpfs $LFS/run
if [ -h $LFS/dev/shm ]; then
	mkdir -pv $LFS/$(readlink $LFS/dev/shm)
fi

