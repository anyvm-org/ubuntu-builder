

[![Build](https://github.com/anyvm-org/ubuntu-builder/actions/workflows/build.yml/badge.svg)](https://github.com/anyvm-org/ubuntu-builder/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/anyvm-org/ubuntu-builder?include_prereleases&sort=semver)](https://github.com/anyvm-org/ubuntu-builder/releases)

Latest: v2.0.1


The image builder for `ubuntu`


All the supported releases are here:



| Release | x86_64 (amd64) | aarch64 (arm64) |
|---------|----------------|-----------------|
| 26.04   |  ✅            |  ❌             |
| 24.04   |  ✅            |  ❌             |
| 22.04   |  ✅            |  ❌             |




How to build:

1. Use the [manual.yml](.github/workflows/manual.yml) to build manually.
   
    Run the workflow manually, you will get a view-only webconsole from the output of the workflow, just open the link in your web browser.
   
    You will also get an interactive VNC connection port from the output, you can connect to the vm by any vnc client.

2. Run the builder locally on your Ubuntu machine.

    Just clone the repo. and run:
    ```bash
    python3 build.py conf/ubuntu-26.04.conf
    ```
   
