How the images are built:

Each image is built automatically in the
[anyvm-org/ubuntu-builder](https://github.com/anyvm-org/ubuntu-builder)
repo's GitHub Actions: it downloads the official Ubuntu server cloud
image, customizes it (serial console, ssh, first-boot setup), boots it
in QEMU, pre-installs the packages listed in the conf, and exports the
disk as a compressed qcow2 image. No interactive installer is run.

Upstream media: the official Ubuntu cloud images from
https://cloud-images.ubuntu.com/.
