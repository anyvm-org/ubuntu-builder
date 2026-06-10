# files/

Static binaries the build needs at run time, committed so CI does not
re-download them on every build.

## u-boot-qemu_2024.01_qemu-riscv64_smode/

`uboot.elf` and `u-boot.bin` extracted from the Ubuntu noble GA package
`u-boot-qemu_2024.01+dfsg-1ubuntu5_all.deb`
(http://archive.ubuntu.com/ubuntu/pool/main/u/u-boot/u-boot-qemu_2024.01+dfsg-1ubuntu5_all.deb),
path `usr/lib/u-boot/qemu-riscv64_smode/` inside the deb.

Why pinned: Ubuntu 22.04 (jammy) riscv64 cloud images boot ONLY via
u-boot's extlinux/sysboot path (/boot on the root partition, empty ESP --
no grub, no EFI fallback). u-boot >= 2024.10 has an LMB rework that makes
the in-place FDT reservation fail on that path ("Failed to reserve memory
for fdt at 0x... / FDT creation failed! hanging...") at any -m size, so
the runner's stock u-boot-qemu (2025.10) cannot boot the image. 2024.01
predates the rework and boots it unattended. See the comment in
conf/ubuntu-22.04-riscv64.conf.

The pin only matters for the build's FIRST boot: hooks/vm_postBuild.sh
converts the artifact to EFI grub boot (installs grub-efi-riscv64 on the
ESP fallback path, disables extlinux), so the exported image boots under
EDK2 UEFI and any u-boot version without this pin.

sha256:
- uboot.elf  9f2a5fe41cd8c9f0f70b1e7f23cb45e24e1848eaf4cb4dd741a271ecdb9e6eab
- u-boot.bin efa1d3d9b7a586154020141e4a24fe4cea2b2be8e173b08f8a82a6595e490474

## qemu-10.2.3-riscv64-noble.tar.zst

`qemu-system-riscv64` 10.2.3 built from the upstream source tarball
(https://download.qemu.org/qemu-10.2.3.tar.xz) inside an ubuntu:24.04
container, so the binary links against noble's libraries -- the same ABI
as the GitHub-hosted ubuntu-24.04 runner (the apt `qemu-system-misc`
install in setup() provides the runtime libs: glib, pixman, slirp, fdt).
configure: `--target-list=riscv64-softmmu` plus `--disable-*` for docs,
GUI, and storage backends the builder never uses. The tree is pruned to
`bin/qemu-system-riscv64` + `share/qemu/{opensbi-riscv64-generic-
fw_dynamic.bin, efi-virtio.rom, keymaps/}` (QEMU finds the datadir
relative to the binary).

Why pinned: Ubuntu 26.04 (resolute) riscv64 cannot run under noble's
stock QEMU 8.2 -- the 7.0 kernel hangs at entry with zero serial output,
and the userspace is built for the RVA23 profile baseline, so any
pre-RVA23 -cpu model kills init with SIGILL. QEMU >= 9.1 provides the
`rva23s64` CPU model; verified end-to-end to the login prompt with this
exact build inside a clean noble container. See the comment in
conf/ubuntu-26.04-riscv64.conf.

sha256:
- qemu-10.2.3-riscv64-noble.tar.zst c618ffc6b4398886021c0eef7d41647eb38ec9981604450a0089101e0a2a8bb7
