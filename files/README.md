# files/

Build inputs the pipeline needs beyond the cloud images.

Small binaries (the u-boot blobs) are committed directly. The pinned QEMU
builds are NOT committed: `build-qemu10.sh` compiles them from source on
the fly -- `hooks/host_beforeBuild.sh` builds the one tarball a conf's
`VM_QEMU_TAR` asks for at the start of each image build, and the
`release-files` job (.github/data/uploadfiles.yml) builds all of them when
publishing release assets.

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

## build-qemu10.sh -> qemu-10.2.3-<arch>-noble.tar.zst

Builds `qemu-system-{riscv64,s390x,ppc64}` 10.2.3 from the upstream
source tarball (https://download.qemu.org/qemu-10.2.3.tar.xz) against the
host distro's libraries -- intended host is ubuntu-24.04 (noble), the
GitHub Actions runner image, hence the "noble" in the tarball names (the
apt qemu packages installed by setup() provide the runtime libs: glib,
pixman, slirp, fdt). Each tarball is pruned to
`qemu10-<arch>/bin/qemu-system-<qemu-arch>` plus only the firmware its
machine type needs under `share/qemu/` (QEMU finds the datadir relative
to the binary):

- riscv64: opensbi-riscv64-generic-fw_dynamic.bin
- s390x:   s390-ccw.img (s390-netboot.img is folded into it in QEMU >= 9.1)
- ppc64le: slof.bin, vgabios-stdvga.bin (pseries SLOF + default std VGA)
- all:     efi-virtio.rom (virtio-net default romfile), keymaps/

Why each arch is pinned to QEMU 10 instead of the runner's stock 8.2:

- **riscv64**: Ubuntu 26.04 (resolute) cannot run under 8.2 -- the 7.0
  kernel hangs at entry with zero serial output, and the userspace is
  built for the RVA23 profile baseline, so any pre-RVA23 -cpu model kills
  init with SIGILL. QEMU >= 9.1 provides the `rva23s64` CPU model;
  verified end-to-end to the login prompt with 10.2.3. See
  conf/ubuntu-26.04-riscv64.conf.
- **s390x**: stock 8.2 TCG intermittently freezes the guest's systemd
  during startup ("Failed to fork off sandboxing environment for
  executing generators: Protocol error" -> "Freezing execution."),
  roughly once per several boots; a build then hangs at the ssh wait
  until the job times out. Rebooting the same disk comes up fine, so it
  is an emulator flake, not image corruption. 10.2.3 carries years of
  s390x TCG fixes. See conf/ubuntu-*-s390x.conf.
- **ppc64le**: under 8.2 pseries TCG with -cpu power9, Ubuntu 22.04
  (jammy) userspace is miscompiled at translation time -- python3.10
  segfaults reproducibly (NULL derefs inside _PyEval_EvalFrameDefault,
  hitting every cloud-init stage and package-data-downloader, 1 or 2
  vCPUs alike), so the image never generates ssh host keys and never
  brings up sshd. -cpu power8 is not an option (jammy ppc64el is POWER9
  baseline; init dies in an illegal-instruction kernel panic). 24.04 /
  26.04 (python 3.12/3.13) do not hit the bug on 8.2 and keep using
  stock QEMU. See conf/ubuntu-22.04-ppc64le.conf.
