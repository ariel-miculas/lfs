# LFS
## Overview
[Linux From Scratch - Version 10.1](https://www.linuxfromscratch.org/lfs/download.html)
## Prerequisites
1. qemu
2. Run `./version_check.sh` to check the required tools

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

# Building LFS system
## Man-pages
```
make install
```

## Iana-Etc
```
cp services protocols /etc
```

## Glibc
```
patch -Np1 -i ../glibc-2.33-fhs-1.patch
```
```
sed -e '402a\      *result = local->data.services[database_index];' \
    -i nss/nss_database.c
```

```
mkdir -v build
cd build
../configure --prefix=/usr \
--disable-werror \
--enable-kernel=3.2 \
--enable-stack-protector=strong \
--with-headers=/usr/include \
libc_cv_slibdir=/lib
make
make check
```

```
touch /etc/ld.so.conf
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
make install
cp -v ../nscd/nscd.conf /etc/nscd.conf
mkdir -pv /var/cache/nscd
```

Install locales:
```
mkdir -pv
 /usr/lib/locale
localedef -i POSIX -f UTF-8 C.UTF-8 2> /dev/null || true
localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
localedef -i de_DE -f ISO-8859-1 de_DE
localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
localedef -i de_DE -f UTF-8 de_DE.UTF-8
localedef -i el_GR -f ISO-8859-7 el_GR
localedef -i en_GB -f UTF-8 en_GB.UTF-8
localedef -i en_HK -f ISO-8859-1 en_HK
localedef -i en_PH -f ISO-8859-1 en_PH
localedef -i en_US -f ISO-8859-1 en_US
localedef -i en_US -f UTF-8 en_US.UTF-8
localedef -i es_MX -f ISO-8859-1 es_MX
localedef -i fa_IR -f UTF-8 fa_IR
localedef -i fr_FR -f ISO-8859-1 fr_FR
localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
localedef -i it_IT -f ISO-8859-1 it_IT
localedef -i it_IT -f UTF-8 it_IT.UTF-8
localedef -i ja_JP -f EUC-JP ja_JP
localedef -i ja_JP -f SHIFT_JIS ja_JP.SIJS 2> /dev/null || true
localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
localedef -i zh_CN -f GB18030 zh_CN.GB18030
localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS
```
Alternatively install all supported locales:
```
make localedata/install-locales
```

```
cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf
passwd: files
group: files
shadow: files
hosts: files dns
networks: files
protocols: files
services: files
ethers: files
rpc: files
# End /etc/nsswitch.conf
EOF
```

Time zone data:
```
tar -xf ../../tzdata2021a.tar.gz
ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}
for tz in etcetera southamerica northamerica europe africa antarctica \
asia australasia backward; do
zic -L /dev/null -d $ZONEINFO ${tz}
zic -L /dev/null -d $ZONEINFO/posix ${tz}
zic -L leapseconds -d $ZONEINFO/right ${tz}
done
cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p America/New_York
unset ZONEINFO
```

```
tzselect
ln -sfv /usr/share/zoneinfo/Europe/Bucharest /etc/localtime
```

Dynamic loader:
```
cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib
EOF
```

## zlib
```
./configure --prefix=/usr
make
make check
make install
mv -v /usr/lib/libz.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libz.so) /usr/lib/libz.so
rm -fv /usr/lib/libz.a
```

## Bzip2
```
patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
make -f Makefile-libbz2_so
make clean
make
make PREFIX=/usr install
cp -v bzip2-shared /bin/bzip2
cp -av libbz2.so* /lib
ln -sv ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so
rm -v /usr/bin/{bunzip2,bzcat,bzip2}
ln -sv bzip2 /bin/bunzip2
ln -sv bzip2 /bin/bzcat
rm -fv /usr/lib/libbz2.a
```

## Xz
```
./configure --prefix=/usr \
--disable-static \
--docdir=/usr/share/doc/xz-5.2.5
make
make check
make install
mv -v /usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} /bin
mv -v /usr/lib/liblzma.so.* /lib
ln -svf ../../lib/$(readlink /usr/lib/liblzma.so) /usr/lib/liblzma.so
```

## Zstd
```
make
make check
make prefix=/usr install
rm -v /usr/lib/libzstd.a
mv -v /usr/lib/libzstd.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libzstd.so) /usr/lib/libzstd.so
```

## File
```
./configure --prefix=/usr
make
make check
make install
```

## Readline
```
sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install
./configure --prefix=/usr \
--disable-static \
--with-curses \
--docdir=/usr/share/doc/readline-8.1
make SHLIB_LIBS="-lncursesw"
make SHLIB_LIBS="-lncursesw" install
mv -v /usr/lib/lib{readline,history}.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libreadline.so) /usr/lib/libreadline.so
ln -sfv ../../lib/$(readlink /usr/lib/libhistory.so ) /usr/lib/libhistory.so
install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.1
```

## M4
```
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
./configure --prefix=/usr
make
make check
make install
```

## Bc
```
PREFIX=/usr CC=gcc ./configure.sh -G -O3
make
make test
make install
```

## Flex
```
./configure --prefix=/usr \
--docdir=/usr/share/doc/flex-2.6.4 \
--disable-static
make
make check
make install
ln -sv flex /usr/bin/lex
```

## Tcl
```
tar -xf ../tcl8.6.11-html.tar.gz --strip-components=1
SRCDIR=$(pwd)
cd unix
./configure --prefix=/usr \
--mandir=/usr/share/man \
$([ "$(uname -m)" = x86_64 ] && echo --enable-64bit)
make
sed -e "s|$SRCDIR/unix|/usr/lib|" \
-e "s|$SRCDIR|/usr/include|" \
-i tclConfig.sh
sed -e
 "s|$SRCDIR/unix/pkgs/tdbc1.1.2|/usr/lib/tdbc1.1.2|" \
-e "s|$SRCDIR/pkgs/tdbc1.1.2/generic|/usr/include|" \
-e "s|$SRCDIR/pkgs/tdbc1.1.2/library|/usr/lib/tcl8.6|" \
-e "s|$SRCDIR/pkgs/tdbc1.1.2|/usr/include|" \
-i pkgs/tdbc1.1.2/tdbcConfig.sh
sed -e "s|$SRCDIR/unix/pkgs/itcl4.2.1|/usr/lib/itcl4.2.1|" \
-e "s|$SRCDIR/pkgs/itcl4.2.1/generic|/usr/include|" \
-e "s|$SRCDIR/pkgs/itcl4.2.1|/usr/include|" \
-i pkgs/itcl4.2.1/itclConfig.sh
unset SRCDIR
make test
make install
chmod -v u+w /usr/lib/libtcl8.6.so
make install-private-headers
ln -sfv tclsh8.6 /usr/bin/tclsh
mv /usr/share/man/man3/{Thread,Tcl_Thread}.3
```

## Expect
```
./configure --prefix=/usr \
--with-tcl=/usr/lib \
--enable-shared \
--mandir=/usr/share/man \
--with-tclinclude=/usr/include
make
make test
make install
ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib
```

## DejaGNU
```
./configure --prefix=/usr
makeinfo --html --no-split -o doc/dejagnu.html doc/dejagnu.texi
makeinfo --plaintext -o doc/dejagnu.txt doc/dejagnu.texi
make install
install -v -dm755 /usr/share/doc/dejagnu-1.6.2
install -v -m644 doc/dejagnu.{html,txt} /usr/share/doc/dejagnu-1.6.2
make check
```

## Binutils
```
expect -c "spawn ls"
sed -i '/@\tincremental_copy/d' gold/testsuite/Makefile.in
mkdir -v build
cd build
../configure --prefix=/usr \
--enable-gold \
--enable-ld=default \
--enable-plugins \
--enable-shared \
--disable-werror \
--enable-64-bit-bfd \
--with-system-zlib
make tooldir=/usr
make -k check
make tooldir=/usr install
rm -fv /usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes}.a
```

## Gmp
```
./configure --prefix=/usr \
--enable-cxx \
--disable-static \
--docdir=/usr/share/doc/gmp-6.2.1
make
make html
make check 2>&1 | tee gmp-check-log
awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log
make install
make install-html
```

## Mpfr
```
./configure --prefix=/usr \
--disable-static \
--enable-thread-safe \
--docdir=/usr/share/doc/mpfr-4.1.0
make
make html
make check
make install
make install-html
```

## Mpc
```
./configure --prefix=/usr \
--disable-static \
--docdir=/usr/share/doc/mpc-1.2.1
make
make html
make check
make install
make install-html
```

## Attr
```
./configure --prefix=/usr \
--bindir=/bin \
--disable-static \
--sysconfdir=/etc \
--docdir=/usr/share/doc/attr-2.4.48
make
make check
make install
mv -v /usr/lib/libattr.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libattr.so) /usr/lib/libattr.so
```

## Acl
```
./configure --prefix=/usr \
--bindir=/bin \
--disable-static \
--libexecdir=/usr/lib \
--docdir=/usr/share/doc/acl-2.2.53
make
make install
The shared library needs to be moved to /lib, and as a result the .so file in /usr/lib will need to be recreated:
mv -v /usr/lib/libacl.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libacl.so) /usr/lib/libacl.so
```

## Libcap
```
sed -i '/install -m.*STA/d' libcap/Makefile
make prefix=/usr lib=lib
make test
make prefix=/usr lib=lib install
for libname in cap psx; do
    mv -v /usr/lib/lib${libname}.so.* /lib
    ln -sfv ../../lib/lib${libname}.so.2 /usr/lib/lib${libname}.so
    chmod -v 755 /lib/lib${libname}.so.2.48
done
```

## Shadow
```
sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\.1 / /' {} \;
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /' {} \;
sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD SHA512:' \
-e 's:/var/spool/mail:/var/mail:' \
-i etc/login.defs
sed -i 's/1000/999/' etc/useradd
touch /usr/bin/passwd
./configure --sysconfdir=/etc \
--with-group-name-max-length=32
make
make install
pwconv
grpconv
sed -i 's/yes/no/' /etc/default/useradd
```

## gcc
```
case $(uname -m) in
x86_64)
sed -e '/m64=/s/lib64/lib/' \
-i.orig gcc/config/i386/t-linux64
;;
esac
mkdir -v build
cd build
../configure --prefix=/usr \
LD=ld \
--enable-languages=c,c++ \
--disable-multilib \
--disable-bootstrap \
--with-system-zlib
make
ulimit -s 32768
chown -Rv tester .
su tester -c "PATH=$PATH make -k check"
../contrib/test_summary
make install
rm -rf /usr/lib/gcc/$(gcc -dumpmachine)/10.2.0/include-fixed/bits/
chown -v -R root:root \
/usr/lib/gcc/*linux-gnu/10.2.0/include{,-fixed}
ln -sv ../usr/bin/cpp /lib
ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/10.2.0/liblto_plugin.so \
/usr/lib/bfd-plugins/
echo 'int main(){}' > dummy.c
cc dummy.c -v -Wl,--verbose &> dummy.log
readelf -l a.out | grep ': /lib'
grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
grep -B4 '^ /usr/include' dummy.log
grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
grep "/lib.*/libc.so.6 " dummy.log
grep found dummy.log
rm -v dummy.c a.out dummy.log
mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
```

## Pkg-config
```
./configure --prefix=/usr \
--with-internal-glib \
--disable-host-tool \
--docdir=/usr/share/doc/pkg-config-0.29.2
make
make check
make install
```

## Ncurses
```
./configure --prefix=/usr \
--mandir=/usr/share/man \
--with-shared \
--without-debug \
--without-normal \
--enable-pc-files \
--enable-widec
make
make install
mv -v /usr/lib/libncursesw.so.6* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libncursesw.so) /usr/lib/libncursesw.so
for lib in ncurses form panel menu ; do
    rm -vf /usr/lib/lib${lib}.so
    echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc /usr/lib/pkgconfig/${lib}.pc
done
rm -vf /usr/lib/libcursesw.so
echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
ln -sfv libncurses.so /usr/lib/libcurses.so
rm -fv /usr/lib/libncurses++w.a
mkdir -v /usr/share/doc/ncurses-6.2
cp -v -R doc/* /usr/share/doc/ncurses-6.2
```

## Sed
```
./configure --prefix=/usr --bindir=/bin
make
make html
chown -Rv tester .
su tester -c "PATH=$PATH make check"
make install
install -d -m755 /usr/share/doc/sed-4.8
install -m644 doc/sed.html /usr/share/doc/sed-4.8
```

## Psmisc
```
./configure --prefix=/usr
make
make install
mv -v /usr/bin/fuser /bin
mv -v /usr/bin/killall /bin
```

## Gettext
```
./configure --prefix=/usr \
--disable-static \
--docdir=/usr/share/doc/gettext-0.21
make
make check
make install
chmod -v 0755 /usr/lib/preloadable_libintl.so
```

## Bison
```
./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.7.5
make
make check
make install
```

## Grep
```
./configure --prefix=/usr --bindir=/bin
make
make check
make install
```

## Bash
```
sed -i '/^bashline.o:.*shmbchar.h/a bashline.o: ${DEFDIR}/builtext.h' Makefile.in
./configure --prefix=/usr \
--docdir=/usr/share/doc/bash-5.1 \
--without-bash-malloc \
--with-installed-readline
make
chown -Rv tester .
su tester << EOF
PATH=$PATH make tests < $(tty)
EOF
make install
mv -vf /usr/bin/bash /bin
exec /bin/bash --login +h
```

## Libtool
```
./configure --prefix=/usr
make
make check TESTSUITEFLAGS=-j8
make install
rm -fv /usr/lib/libltdl.a
```

## Gdbm
```
./configure --prefix=/usr \
--disable-static \
--enable-libgdbm-compat
make
make check
make install
```

## Gperf
```
./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.1
make
make -j1 check
make install
```

## Expat
```
./configure --prefix=/usr \
--disable-static \
--docdir=/usr/share/doc/expat-2.2.10
make
make check
make install
install -v -m644 doc/*.{html,png,css} /usr/share/doc/expat-2.2.10
```

## Inetutils
```
./configure --prefix=/usr \
--localstatedir=/var \
--disable-logger \
--disable-whois \
--disable-rcp \
--disable-rexec \
--disable-rlogin \
--disable-rsh \
--disable-servers
make
make check
make install
mv -v /usr/bin/{hostname,ping,ping6,traceroute} /bin
mv -v /usr/bin/ifconfig /sbin
```

## Perl
```
export BUILD_ZLIB=False
export BUILD_BZIP2=0
sh Configure -des \
-Dprefix=/usr \
-Dvendorprefix=/usr \
-Dprivlib=/usr/lib/perl5/5.32/core_perl \
-Darchlib=/usr/lib/perl5/5.32/core_perl \
-Dsitelib=/usr/lib/perl5/5.32/site_perl \
-Dsitearch=/usr/lib/perl5/5.32/site_perl \
-Dvendorlib=/usr/lib/perl5/5.32/vendor_perl \
-Dvendorarch=/usr/lib/perl5/5.32/vendor_perl \
-Dman1dir=/usr/share/man/man1 \
-Dman3dir=/usr/share/man/man3 \
-Dpager="/usr/bin/less -isR" \
-Duseshrplib \
-Dusethreads
make -j8
make test
make install
unset BUILD_ZLIB BUILD_BZIP2
```

## XML::Parser
```
perl Makefile.PL
make
make test
make install
```

## Intltool
```
sed -i 's:\\\${:\\\$\\{:' intltool-update.in
./configure --prefix=/usr
make
make check
make install
install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
```

## Autoconf
```
./configure --prefix=/usr
make
make check
make install
```

## Automake
```
sed -i "s/''/etags/" t/tags-lisp-space.sh
./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.16.3
make
make -j4 check
make install
```

## Kmod
```
./configure --prefix=/usr \
--bindir=/bin \
--sysconfdir=/etc \
--with-rootlibdir=/lib \
--with-xz \
--with-zstd \
--with-zlib
make
make install
for target in depmod insmod lsmod modinfo modprobe rmmod; do
    ln -sfv ../bin/kmod /sbin/$target
done
ln -sfv kmod /bin/lsmod
```

## Libelf
```
./configure --prefix=/usr \
--disable-debuginfod \
--enable-libdebuginfod=dummy \
--libdir=/lib
make
make check
make -C libelf install
install -vm644 config/libelf.pc /usr/lib/pkgconfig
rm /lib/libelf.a
```

## Libffi
```
./configure --prefix=/usr --disable-static --with-gcc-arch=native
make
make check
make install
```

## Openssl
```
./config --prefix=/usr \
--openssldir=/etc/ssl \
--libdir=lib \
shared \
zlib-dynamic
make
make test
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install
mv -v /usr/share/doc/openssl /usr/share/doc/openssl-1.1.1j
cp -vfr doc/* /usr/share/doc/openssl-1.1.1j
```

## Python3
```
./configure --prefix=/usr \
--enable-shared \
--with-system-expat \
--with-system-ffi \
--with-ensurepip=yes
make
make test
make install
install -v -dm755 /usr/share/doc/python-3.9.2/html
tar --strip-components=1 \
--no-same-owner \
--no-same-permissions \
-C /usr/share/doc/python-3.9.2/html \
-xvf ../python-3.9.2-docs-html.tar.bz2
```

## Ninja
```
export NINJAJOBS=8
sed -i '/int Guess/a \
int j = 0;\
char* jobs = getenv( "NINJAJOBS" );\
if ( jobs != NULL ) j = atoi( jobs );\
if ( j > 0 ) return j;\
' src/ninja.cc
python3 configure.py --bootstrap
./ninja ninja_test
./ninja_test --gtest_filter=-SubprocessTest.SetWithLots
install -vm755 ninja /usr/bin/
install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 misc/zsh-completion /usr/share/zsh/site-functions/_ninja
```

## Meson
```
python3 setup.py build
python3 setup.py install --root=dest
cp -rv dest/* /
```

## Coreutils
```
patch -Np1 -i ../coreutils-8.32-i18n-1.patch
sed -i '/test.lock/s/^/#/' gnulib-tests/gnulib.mk
autoreconf -fiv
FORCE_UNSAFE_CONFIGURE=1 ./configure \
--prefix=/usr \
--enable-no-install-program=kill,uptime
make
make NON_ROOT_USERNAME=tester check-root
echo "dummy:x:102:tester" >> /etc/group
chown -Rv tester .
su tester -c "PATH=$PATH make RUN_EXPENSIVE_TESTS=yes check"
sed -i '/dummy/d' /etc/group
make install
mv -v /usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} /bin
mv -v /usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} /bin
mv -v /usr/bin/{rmdir,stty,sync,true,uname} /bin
mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
mv -v /usr/bin/{head,nice,sleep,touch} /bin
```

## Check
```
./configure --prefix=/usr --disable-static
make
make check
make docdir=/usr/share/doc/check-0.15.2 install
```

## Diffutils
```
./configure --prefix=/usr
make
make check
make install
```

## Gawk
```
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr
make
make check
make install
mkdir -v /usr/share/doc/gawk-5.1.0
cp -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/gawk-5.1.0
```

## Findutils
```
./configure --prefix=/usr --localstatedir=/var/lib/locate
make
chown -Rv tester .
su tester -c "PATH=$PATH make check"
make install
mv -v /usr/bin/find /bin
sed -i 's|find:=${BINDIR}|find:=/bin|' /usr/bin/updatedb
```

## Groff
```
PAGE=A4 ./configure --prefix=/usr
make -j1
make install
```

## Grub
```
sed "s/gold-version/& -R .note.gnu.property/" \
-i Makefile.in grub-core/Makefile.in
./configure --prefix=/usr \
--sbindir=/sbin \
--sysconfdir=/etc \
--disable-efiemu \
--disable-werror
make
make install
mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions
```

## Less
```
./configure --prefix=/usr --sysconfdir=/etc
make
make install
```

## Gzip
```
./configure --prefix=/usr
make
make check
make install
mv -v /usr/bin/gzip /bin
```

## IProute
```
sed -i /ARPD/d Makefile
rm -fv man/man8/arpd.8
sed -i 's/.m_ipt.o//' tc/Makefile
make
make DOCDIR=/usr/share/doc/iproute2-5.10.0 install
```

## Kbd
```
patch -Np1 -i ../kbd-2.4.0-backspace-1.patch
sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
./configure --prefix=/usr --disable-vlock
make
make check
make install
mkdir -v /usr/share/doc/kbd-2.4.0
cp -R -v docs/doc/* /usr/share/doc/kbd-2.4.0
```

## Libpipeline
```
./configure --prefix=/usr
make
make check
make install
```

## Make
```
./configure --prefix=/usr
make
make check
make install
```

## Patch
```
./configure --prefix=/usr
make
make check
make install
```

## Man-DB
```
./configure --prefix=/usr \
--docdir=/usr/share/doc/man-db-2.9.4 \
--sysconfdir=/etc \
--disable-setuid \
--enable-cache-owner=bin \
--with-browser=/usr/bin/lynx \
--with-vgrind=/usr/bin/vgrind \
--with-grap=/usr/bin/grap \
--with-systemdtmpfilesdir= \
--with-systemdsystemunitdir=
make
make check
make install
```

## Tar
```
FORCE_UNSAFE_CONFIGURE=1 \
./configure --prefix=/usr \
--bindir=/bin
make
make check
make install
make -C doc install-html docdir=/usr/share/doc/tar-1.34
```

## Texinfo
```
./configure --prefix=/usr
make
make check
make install
make TEXMF=/usr/share/texmf install-tex
pushd /usr/share/info
    rm -v dir
    for f in *
        do install-info $f dir 2>/dev/null
    done
popd
```

## Vim
```
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
./configure --prefix=/usr
make
chown -Rv tester .
su tester -c "LANG=en_US.UTF-8 make -j1 test" &> vim-test.log
make install
ln -sv vim /usr/bin/vi
for L in /usr/share/man/{,*/}man1/vim.1; do
    ln -sv vim.1 $(dirname $L)/vi.1
done
ln -sv ../vim/vim82/doc /usr/share/doc/vim-8.2.2433
cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc
" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1
set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
    set background=dark
endif
" End /etc/vimrc
EOF
```

## Eudev
```
./configure --prefix=/usr \
--bindir=/sbin \
--sbindir=/sbin \
--libdir=/usr/lib \
--sysconfdir=/etc \
--libexecdir=/lib \
--with-rootprefix= \
--with-rootlibdir=/lib \
--enable-manpages \
--disable-static
make
mkdir -pv /lib/udev/rules.d
mkdir -pv /etc/udev/rules.d
make check
make install
tar -xvf ../udev-lfs-20171102.tar.xz
make -f udev-lfs-20171102/Makefile.lfs install
udevadm hwdb --update
```

## Procps-ng
```
./configure --prefix=/usr \
--exec-prefix= \
--libdir=/usr/lib \
--docdir=/usr/share/doc/procps-ng-3.3.17 \
--disable-static \
--disable-kill
make
make check
make install
mv -v /usr/lib/libprocps.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libprocps.so) /usr/lib/libprocps.so
```

## Util-linux
```
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
--without-systemd \
--without-systemdsystemunitdir \
runstatedir=/run
make
chown -Rv tester .
su tester -c "make -k check"
make install
```

## E2fsprogs
```
mkdir -v build
cd build
../configure --prefix=/usr \
--bindir=/bin \
--with-root-prefix="" \
--enable-elf-shlibs \
--disable-libblkid \
--disable-libuuid \
--disable-uuidd \
--disable-fsck
make
make check
make install
rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
gunzip -v /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
makeinfo -o doc/com_err.info ../lib/et/com_err.texinfo
install -v -m644 doc/com_err.info /usr/share/info
install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info
```

## Sysklogd
```
sed -i '/Error loading kernel symbols/{n;n;d}' ksym_mod.c
sed -i 's/union wait/int/' syslogd.c
make
make BINDIR=/sbin install
cat > /etc/syslog.conf << "EOF"
# Begin /etc/syslog.conf
auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *
# End /etc/syslog.conf
EOF
```

## Sysvinit
```
patch -Np1 -i ../sysvinit-2.98-consolidated-1.patch
make
make install
```

## Stripping
```
save_lib="ld-2.33.so libc-2.33.so libpthread-2.33.so libthread_db-1.0.so"
cd /lib
for LIB in $save_lib; do
    objcopy --only-keep-debug $LIB $LIB.dbg
    strip --strip-unneeded $LIB
    objcopy --add-gnu-debuglink=$LIB.dbg $LIB
done
save_usrlib="libquadmath.so.0.0.0 libstdc++.so.6.0.28
libitm.so.1.0.0 libatomic.so.1.2.0"
cd /usr/lib
for LIB in $save_usrlib; do
    objcopy --only-keep-debug $LIB $LIB.dbg
    strip --strip-unneeded $LIB
    objcopy --add-gnu-debuglink=$LIB.dbg $LIB
done
unset LIB save_lib save_usrlib
```

```
find /usr/lib -type f -name \*.a \
    -exec strip --strip-debug {} ';'
find /lib /usr/lib -type f -name \*.so* ! -name \*dbg \
    -exec strip --strip-unneeded {} ';'
find /{bin,sbin} /usr/{bin,sbin,libexec} -type f \
    -exec strip --strip-all {} ';'
```

## Clean up
```
rm -rf /tmp/*
```

```
logout
chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM="$TERM" \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/bin:/usr/bin:/sbin:/usr/sbin \
    /bin/bash --login
```

```
find /usr/lib /usr/libexec -name \*.la -delete
find /usr -depth -name $(uname -m)-lfs-linux-gnu\* | xargs rm -rf
rm -rf /tools
userdel -r tester
```

# Resources
https://nilisnotnull.blogspot.com/2015/02/installing-lfs-with-qemu.html?m=0
