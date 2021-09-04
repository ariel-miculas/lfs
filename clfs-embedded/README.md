# CLFS-embedded
## Overview
http://clfs.org/view/clfs-embedded/x86/
https://github.com/cross-lfs/clfs-embedded
https://github.com/cross-lfs/bootscripts-embedded
https://github.com/dslm4515/Musl-LFS

### Musl cross make
https://github.com/richfelker/musl-cross-make

## Build preparations
### Partitioning scheme:
```
NAME          MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINTS
loop0           7:0    0    30G  0 loop
├─loop0p1     259:0    0   200M  0 part
├─loop0p2     259:1    0     4G  0 part  [SWAP]
├─loop0p3     259:2    0  23.8G  0 part  /mnt/lfs
└─loop0p4     259:3    0     2G  0 part  /mnt/clfs
```
### Build directory
```
sudo mkdir -p /mnt/clfs
export CLFS=/mnt/clfs
sudo chmod 777 ${CLFS}
mkdir -v ${CLFS}/sources
# Setup a loopback device so the image file is accessible as a block device
sudo losetup -P /dev/loop0 ./lfs-target-disk.img
sudo mount -v -t ext4 /dev/loop0p4 $CLFS
```

### Required packages
```
mkdir ./sources
wget --input-file=wget-list --continue --directory-prefix=./sources
pushd sources
md5sum -c ../md5sum
popd
```

### clfs user
```
sudo groupadd clfs
sudo useradd -s /bin/bash -g clfs -m -k /dev/null clfs
sudo passwd clfs
sudo chown -Rv clfs ${CLFS}
su - clfs
```

### clfs environment (run as user clfs)
#### bash_profile
```
cat > ~/.bash_profile << "EOF"
exec env -i HOME=${HOME} TERM=${TERM} PS1='\u:\w\$ ' /bin/bash
EOF
```
#### bashrc
```
cat > ~/.bashrc << "EOF"
set +h
umask 022
CLFS=/mnt/clfs
LC_ALL=POSIX
PATH=${CLFS}/cross-tools/bin:/bin:/usr/bin
export CLFS LC_ALL PATH
EOF
```
#### Source the profile
```
source ~/.bash_profile
```

## Cross-compilation tools
### Cflags and Cxxflags
```
unset CFLAGS
echo unset CFLAGS >> ~/.bashrc
unset CXXFLAGS
echo unset CXXFLAGS >> ~/.bashrc
```

### Build variables
```
export CLFS_HOST=$(echo ${MACHTYPE} | sed "s/-[^-]*/-cross/")
export CLFS_TARGET=x86_64-linux-musl
export CLFS_CPU=x86-64
export CLFS_ARCH="x86_64"

echo export CLFS_HOST=\""${CLFS_HOST}\"" >> ~/.bashrc
echo export CLFS_TARGET=\""${CLFS_TARGET}\"" >> ~/.bashrc
echo export CLFS_ARCH=\""${CLFS_ARCH}\"" >> ~/.bashrc
echo export CLFS_CPU=\""${CLFS_CPU}\"" >> ~/.bashrc
```

### Systroot
```
mkdir -p ${CLFS}/cross-tools/${CLFS_TARGET}
# ln -sfv ${CLFS}/cross-tools/${CLFS_TARGET} ${CLFS}/cross-tools/${CLFS_TARGET}/usr
```

### Linux kernel headers
```
make mrproper
make ARCH=${CLFS_ARCH} headers
mkdir -pv ${CLFS}/cross-tools/${CLFS_TARGET}/include
cp -rv usr/include/* ${CLFS}/cross-tools/${CLFS_TARGET}/include
rm -v ${CLFS}/cross-tools/${CLFS_TARGET}/include/Makefile
```

### Binutils
```
mkdir -v build
cd build
../configure \
   --prefix=${CLFS}/cross-tools \
   --target=${CLFS_TARGET} \
   --with-sysroot=${CLFS}/cross-tools/${CLFS_TARGET} \
   --disable-nls \
   --disable-multilib \
   --disable-Werror
make configure-host
make -j4
make install
```

### Gcc-10.2.0 static
```
tar xf ../mpfr-4.1.0.tar.xz
mv -v mpfr-4.1.0 mpfr
tar xf ../gmp-6.2.1.tar.xz
mv -v gmp-6.2.1 gmp
tar xf ../mpc-1.2.1.tar.gz
mv -v mpc-1.2.1 mpc
sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
mkdir -v build
cd build
../configure \
  --prefix=${CLFS}/cross-tools \
  --build=${CLFS_HOST} \
  --host=${CLFS_HOST} \
  --target=${CLFS_TARGET} \
  --with-sysroot=${CLFS}/cross-tools/${CLFS_TARGET} \
  --disable-nls  \
  --disable-shared \
  --without-headers \
  --with-newlib \
  --disable-decimal-float \
  --disable-libitm \
  --disable-libvtv \
  --disable-libgomp \
  --disable-libssp \
  --disable-libatomic \
  --disable-libstdcxx \
  --disable-libquadmath \
  --disable-libsanitizer \
  --disable-threads \
  --enable-languages=c \
  --disable-multilib \
  --with-mpfr-include=$(pwd)/../mpfr/src \
  --with-mpfr-lib=$(pwd)/mpfr/src/.libs \
  --with-arch=${CLFS_CPU} \
  --enable-clocale=generic
make -j4 all-gcc all-target-libgcc
make install-gcc install-target-libgcc
```

### Musl-1.1.16
```
./configure \
  CROSS_COMPILE=${CLFS_TARGET}- \
  --prefix=/ \
  --target=${CLFS_TARGET}
make -j4
DESTDIR=${CLFS}/cross-tools/${CLFS_TARGET} make install
# Add missing directory and link
mkdir -v ${CLFS}/cross-tools/${CLFS_TARGET}/usr
cp -vR include ${CLFS}/cross-tools/${CLFS_TARGET}/usr
```
### Gcc-10.2.0 final
```
tar xf ../mpfr-4.1.0.tar.xz
mv -v mpfr-4.1.0 mpfr
tar xf ../gmp-6.2.1.tar.xz
mv -v gmp-6.2.1 gmp
tar xf ../mpc-1.2.1.tar.gz
mv -v mpc-1.2.1 mpc
sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
mkdir -v build
cd build
../configure \
  --prefix=${CLFS}/cross-tools \
  --build=${CLFS_HOST} \
  --host=${CLFS_HOST} \
  --target=${CLFS_TARGET} \
  --with-sysroot=${CLFS}/cross-tools/${CLFS_TARGET} \
  --disable-multilib \
  --disable-nls \
  --enable-shared \
  --enable-languages=c,c++ \
  --enable-threads=posix \
  --enable-clocale=generic \
  --enable-libstdcxx-time \
  --enable-fully-dynamic-string \
  --disable-symvers \
  --disable-libsanitizer \
  --disable-lto-plugin \
  --disable-libssp \
  --with-mpfr-include=$(pwd)/../mpfr/src \
  --with-mpfr-lib=$(pwd)/mpfr/src/.libs \
  --with-arch=${CLFS_CPU}
make -j4 2>&1 | tee build_log.txt
make install
```

### Toolchain variables
Our sysroot is actually ${CLFS}, so there's no need to set it to `${CLFS}/targetfs` as per the documentation.

```
echo export CC=\""${CLFS_TARGET}-gcc --sysroot=${CLFS}\"" >> ~/.bashrc
echo export CXX=\""${CLFS_TARGET}-g++ --sysroot=${CLFS}\"" >> ~/.bashrc
echo export AR=\""${CLFS_TARGET}-ar\"" >> ~/.bashrc
echo export AS=\""${CLFS_TARGET}-as\"" >> ~/.bashrc
echo export LD=\""${CLFS_TARGET}-ld --sysroot=${CLFS}\"" >> ~/.bashrc
echo export RANLIB=\""${CLFS_TARGET}-ranlib\"" >> ~/.bashrc
echo export READELF=\""${CLFS_TARGET}-readelf\"" >> ~/.bashrc
echo export STRIP=\""${CLFS_TARGET}-strip\"" >> ~/.bashrc
source ~/.bashrc
```
