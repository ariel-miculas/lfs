# LFS
## Overview
[Linux From Scratch - Version 10.1](https://www.linuxfromscratch.org/lfs/download.html)
## Prerequisites
1. qemu

## Running
```
make run
```

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
❯ sudo su -
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

# LFS cross toolchain
## binutils
```
../configure --prefix=$LFS/tools \
--with-sysroot=$LFS \
--target=$LFS_TGT \
--disable-nls \
--disable-werror \
&& make \
&& make install
```

## gcc
```
tar -xf ../mpfr-4.1.0.tar.xz
mv -v mpfr-4.1.0 mpfr
tar -xf ../gmp-6.2.1.tar.xz
mv -v gmp-6.2.1 gmp
tar -xf ../mpc-1.2.1.tar.gz
mv -v mpc-1.2.1 mpc
```
```
case $(uname -m) in
x86_64)
sed -e '/m64=/s/lib64/lib/' \
-i.orig gcc/config/i386/t-linux64
;;
esac
```
```
mkdir -v build
cd build
```
```
../configure \
--target=$LFS_TGT \
--prefix=$LFS/tools \
--with-glibc-version=2.11 \
--with-sysroot=$LFS \
--with-newlib \
--without-headers \
--enable-initfini-array \
--disable-nls \
--disable-shared \
--disable-multilib \
--disable-decimal-float \
--disable-threads \
--disable-libatomic \
--disable-libgomp \
--disable-libquadmath \
--disable-libssp \
--disable-libvtv \
--disable-libstdcxx \
--enable-languages=c,c++
```
```
make && make install
```
```
cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
`dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/install-tools/include/limits.h
```

## Linux API headers
```
make mrproper
```

```
make headers
find usr/include -name '.*' -delete
rm usr/include/Makefile
cp -rv usr/include $LFS/usr
```

## Glibc
```
case $(uname -m) in
i?86)
 ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
;;
x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
;;
esac
```

```
patch -Np1 -i ../glibc-2.33-fhs-1.patch
```

```
mkdir -v build
cd build
../configure \
--prefix=/usr \
--host=$LFS_TGT \
--build=$(../scripts/config.guess) \
--enable-kernel=3.2 \
--with-headers=$LFS/usr/include \
libc_cv_slibdir=/lib
make
make DESTDIR=$LFS install
```

```
$LFS/tools/libexec/gcc/$LFS_TGT/10.2.0/install-tools/mkheaders
```

## Libstdc++
```
mkdir -v build
cd build
../libstdc++-v3/configure \
--host=$LFS_TGT \
--build=$(../config.guess) \
--prefix=/usr \
--disable-multilib \
--disable-nls \
--disable-libstdcxx-pch \
--with-gxx-include-dir=/tools/$LFS_TGT/include/c++/10.2.0
make
make DESTDIR=$LFS install
```

# LFS Temporary tools
## M4
```
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
./configure --prefix=/usr \
--host=$LFS_TGT \
--build=$(build-aux/config.guess)
make
make DESTDIR=$LFS install
```

## ncurses
```
sed -i s/mawk// configure
mkdir build
pushd build
../configure
make -C include
make -C progs tic
popd
```

```
./configure --prefix=/usr \
--host=$LFS_TGT \
--build=$(./config.guess) \
--mandir=/usr/share/man \
--with-manpage-format=normal \
--with-shared \
--without-debug \
--without-ada \
--without-normal \
--enable-widec
make
make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install
echo "INPUT(-lncursesw)" > $LFS/usr/lib/libncurses.so
mv -v $LFS/usr/lib/libncursesw.so.6* $LFS/lib
ln -sfv ../../lib/$(readlink $LFS/usr/lib/libncursesw.so) $LFS/usr/lib/libncursesw.so
```

## Bash
```
./configure --prefix=/usr \
--build=$(support/config.guess) \
--host=$LFS_TGT \
--without-bash-malloc
```

```
make
make DESTDIR=$LFS install
mv $LFS/usr/bin/bash $LFS/bin/bash
ln -sv bash $LFS/bin/sh
```

## Coreutils
```
./configure --prefix=/usr \
--host=$LFS_TGT \
--build=$(build-aux/config.guess) \
--enable-install-program=hostname \
--enable-no-install-program=kill,uptime
```

```
make
make DESTDIR=$LFS install
mv -v $LFS/usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} $LFS/bin
mv -v $LFS/usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} $LFS/bin
mv -v $LFS/usr/bin/{rmdir,stty,sync,true,uname} $LFS/bin
mv -v $LFS/usr/bin/{head,nice,sleep,touch} $LFS/bin
mv -v $LFS/usr/bin/chroot $LFS/usr/sbin
mkdir -pv $LFS/usr/share/man/man8
mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/m
sed -i 's/"1"/"8"/' $LFS/usr/share/man/m
```

## Diffutils
```
./configure --prefix=/usr --host=$LFS_TGT
make
make DESTDIR=$LFS install
```

## File
```
mkdir build
pushd build
../configure --disable-bzlib \
--disable-libseccomp \
--disable-xzlib \
--disable-zlib
make
popd
```

```
./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
make FILE_COMPILE=$(pwd)/build/src/file
make DESTDIR=$LFS install
```

## Findutils
```
./configure --prefix=/usr \
--host=$LFS_TGT \
--build=$(build-aux/config.guess)
make
make DESTDIR=$LFS install
mv -v $LFS/usr/bin/find $LFS/bin
sed -i 's|find:=${BINDIR}|find:=/bin|' $LFS/usr/bin/updatedb
```

## Gawk
```
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr \
--host=$LFS_TGT \
--build=$(./config.guess)
make
make DESTDIR=$LFS install
```
## Grep
```
./configure --prefix=/usr \
--host=$LFS_TGT \
--bindir=/bin
make
make DESTDIR=$LFS install
```

## Gzip
```
./configure --prefix=/usr --host=$LFS_TGT
make
make DESTDIR=$LFS install
mv -v $LFS/usr/bin/gzip $LFS/bin
```

## Make
```
./configure --prefix=/usr \
--without-guile \
--host=$LFS_TGT \
--build=$(build-aux/config.guess)
make
make DESTDIR=$LFS install
```

## Patch
```
./configure --prefix=/usr \
--host=$LFS_TGT \
--build=$(build-aux/config.guess)
make
make DESTDIR=$LFS install
```

## Sed
```
./configure --prefix=/usr \
--host=$LFS_TGT \
--bindir=/bin
make
make DESTDIR=$LFS install
```

## Tar
```
./configure --prefix=/usr \
--host=$LFS_TGT \
--build=$(build-aux/config.guess) \
--bindir=/bin
make
make DESTDIR=$LFS install
```

## Xz
```
./configure --prefix=/usr \
--host=$LFS_TGT \
--build=$(build-aux/config.guess) \
--disable-static \
--docdir=/usr/share/doc/xz-5.2.5
make
make DESTDIR=$LFS install
mv -v $LFS/usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} $LFS/bin
mv -v $LFS/usr/lib/liblzma.so.* $LFS/lib
ln -svf ../../lib/$(readlink $LFS/usr/lib/liblzma.so) $LFS/usr/lib/liblzma.so
```

## Binutils (pass 2)
```
mkdir -v build
cd build
../configure \
--prefix=/usr \
--build=$(../config.guess) \
--host=$LFS_TGT \
--disable-nls \
--enable-shared \
--disable-werror \
--enable-64-bit-bfd
make
make DESTDIR=$LFS install
install -vm755 libctf/.libs/libctf.so.0.0.0 $LFS/usr/lib
```

## Gcc (pass 2)
```
tar -xf ../mpfr-4.1.0.tar.xz
mv -v mpfr-4.1.0 mpfr
tar -xf ../gmp-6.2.1.tar.xz
mv -v gmp-6.2.1 gmp
tar -xf ../mpc-1.2.1.tar.gz
mv -v mpc-1.2.1 mpc
```

```
case $(uname -m) in
x86_64)
sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
;;
esac
```

```
mkdir -v build
cd build
mkdir -pv $LFS_TGT/libgcc
ln -s ../../../libgcc/gthr-posix.h $LFS_TGT/libgcc/gthr-default.h
../configure \
--build=$(../config.guess) \
--host=$LFS_TGT \
--prefix=/usr \
CC_FOR_TARGET=$LFS_TGT-gcc \
--with-build-sysroot=$LFS \
--enable-initfini-array \
--disable-nls \
--disable-multilib \
--disable-decimal-float \
--disable-libatomic \
--disable-libgomp \
--disable-libquadmath \
--disable-libssp \
--disable-libvtv \
--disable-libstdcxx \
--enable-languages=c,c++
```

```
make
make DESTDIR=$LFS install
ln -sv gcc $LFS/usr/bin/cc
```

# LFS chroot temporary tools
## Root commands
```
sudo su -
export LFS=/mnt/lfs
chown -R root:root $LFS/{usr,lib,var,etc,bin,sbin,tools}
case $(uname -m) in
x86_64) chown -R root:root $LFS/lib64 ;;
esac
```

```
mkdir -pv $LFS/{dev,proc,sys,run}
mknod -m 600 $LFS/dev/console c 5 1
mknod -m 666 $LFS/dev/null c 1 3
mount -v --bind /dev $LFS/dev
mount -v --bind /dev/pts $LFS/dev/pts
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount -vt tmpfs tmpfs $LFS/run
if [ -h $LFS/dev/shm ]; then
mkdir -pv $LFS/$(readlink $LFS/dev/shm)
fi
```

## Chroot commands
### Enter chroot (execute as root)
```
chroot "$LFS" /usr/bin/env -i \
HOME=/root \
TERM="$TERM" \
PS1='(lfs chroot) \u:\w\$ ' \
PATH=/bin:/usr/bin:/sbin:/usr/sbin \
/bin/bash --login +h
```

### Creating directories/files/symlinks
```
mkdir -pv /{boot,home,mnt,opt,srv}
mkdir -pv /etc/{opt,sysconfig}
mkdir -pv /lib/firmware
mkdir -pv /media/{floppy,cdrom}
mkdir -pv /usr/{,local/}{bin,include,lib,sbin,src}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv /usr/{,local/}share/man/man{1..8}
mkdir -pv /var/{cache,local,log,mail,opt,spool}
mkdir -pv /var/lib/{color,misc,locate}
ln -sfv /run /var/run
ln -sfv /run/lock /var/lock
install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp
```

```
ln -sv /proc/self/mounts /etc/mtab
echo "127.0.0.1 localhost $(hostname)" > /etc/hosts
```

```
cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF
```

```
cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
uuidd:x:80:
wheel:x:97:
nogroup:x:99:
users:x:999:
EOF
```

```
echo "tester:x:$(ls -n $(tty) | cut -d" " -f3):101::/home/tester:/bin/bash" >> /etc/passwd
echo "tester:x:101:" >> /etc/group
install -o tester -d /home/tester
```

```
exec /bin/bash --login +h
```

```
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664 /var/log/lastlog
chmod -v 600 /var/log/btmp
```

### Libstdc++ (pass 2)
(gcc sources)

```
ln -s gthr-posix.h libgcc/gthr-default.h
mkdir -v build
cd build
../libstdc++-v3/configure \
CXXFLAGS="-g -O2 -D_GNU_SOURCE" \
--prefix=/usr \
--disable-multilib \
--disable-nls \
--host=$(uname -m)-lfs-linux-gnu \
--disable-libstdcxx-pch
make
make install
```

### Gettext
```
./configure --disable-shared
make
cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
```

### Bison
```
./configure --prefix=/usr \
--docdir=/usr/share/doc/bison-3.7.5
make
make install
```
### Perl
```
sh Configure -des \
-Dprefix=/usr \
-Dvendorprefix=/usr \
-Dprivlib=/usr/lib/perl5/5.32/core_perl \
-Darchlib=/usr/lib/perl5/5.32/core_perl \
-Dsitelib=/usr/lib/perl5/5.32/site_perl \
-Dsitearch=/usr/lib/perl5/5.32/site_perl \
-Dvendorlib=/usr/lib/perl5/5.32/vendor_perl \
-Dvendorarch=/usr/lib/perl5/5.32/vendor_perl
make
make install
```
### Python 3.9
```
./configure --prefix=/usr \
--enable-shared \
--without-ensurepip
make
make install
```

### Texinfo
```
./configure --prefix=/usr
make
make install
```

### Util-linux
```
mkdir -pv /var/lib/hwclock
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime \
--docdir=/usr/share/doc/util-linux-2.36.2 \
--disable-chfn-chsh \
--disable-login \
--disable-nologin \
--disable-su \
--disable-setpriv \
--disable-runuser \
--disable-pylibmount \
--disable-static \
--without-python \
runstatedir=/run
make
make install
```

### Cleanup
```
find /usr/{lib,libexec} -name \*.la -delete
rm -rf /usr/share/{info,man,doc}/*
```

#### Stripping
```
exit
umount $LFS/dev{/pts,}
umount $LFS/{sys,proc,run}
strip --strip-debug $LFS/usr/lib/*
strip --strip-unneeded $LFS/usr/{,s}bin/*
strip --strip-unneeded $LFS/tools/bin/*
```

#### Backup
```
cd $LFS &&
tar -cJpf $HOME/lfs-temp-tools-10.1.tar.xz .
```
#### Restore
```
cd $LFS &&
rm -rf ./* &&
tar -xpf $HOME/lfs-temp-tools-10.1.tar.xz
```

# Resources
https://nilisnotnull.blogspot.com/2015/02/installing-lfs-with-qemu.html?m=0
