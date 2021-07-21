.PHONY: run

run:
	qemu-system-x86_64 -enable-kvm -m 256 -hda lfs-target-disk.img
