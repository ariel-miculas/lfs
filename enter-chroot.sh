#!/bin/bash
if [ -z "$LFS" ]; then
	export LFS=/dev/lfs
fi
chroot "$LFS" /usr/bin/env -i \
HOME=/root \
TERM="$TERM" \
PS1='(lfs chroot) \u:\w\$ ' \
PATH=/bin:/usr/bin:/sbin:/usr/sbin \
/bin/bash --login +h

