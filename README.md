## Supported boards

Soc | Boards |
|:--|:--|
| Allwinner H6 | Orange Pi 3/3 LTS |
| Allwinner H616 | Orange Pi Zero2/Zero2w/Zero3 | 
| Allwinner T527 | Orange Pi 4A |
| Allwinner A733 | Orange Pi 4Pro | 
| Rockchip RK3399 | Orange Pi 4/4B/4 LTS/800 |
| Rockchip RK3566 | Orange Pi 3B/CM4 |
| Rockchip RK3588S | Orange Pi 5/5B/5Pro/CM5/CM5-tablet |
| Rockchip RK3588 | Orange Pi 5Plus/5MAX/5Ultra |
| Cix P1 | Orange Pi 6Plus |
| Starfive  JH7110 | Orange Pi RV |
| Ky X1 | Orange Pi RV2/R2S |

## Download links

- 中文链接：     http://www.orangepi.cn
- English link：http://www.orangepi.org

## Supported Host Systems
- Ubuntu 22.04

## Headless A733 Vulkan

CLI images for Orange Pi Zero 3W, 4 Pro and Zero 4 on the `current` kernel
include the PowerVR Vulkan runtime, GPU firmware and `pvrsrvkm` autoload.
The installer uses the vendor's DDK 24.2.6603887 archive from
`rk-rootfs-build`'s `sun60iw2_packages` branch (`bullseye/xserver/`), verifies
its SHA-256, and installs only the Vulkan runtime into `/usr/lib/powervr`.
Debian's Vulkan loader and desktop components remain owned by their packages.
The module's kernel release and the BSP DDK version must match before installation.

Build a Trixie CLI image on the supported build host:

```bash
sudo ./build.sh BOARD=orangepizero3w BRANCH=current RELEASE=trixie \
  BUILD_OPT=image BUILD_DESKTOP=no BUILD_MINIMAL=yes KERNEL_CONFIGURE=no
```

Run the installer regression checks on Linux with `dpkg-deb` and the downloaded
vendor package (privileged operations are stubbed; no GPU is required):

```bash
bash scripts/tests/test-sun60iw2-gpu.sh \
  external/cache/sources/sun60iw2_packages/bullseye/xserver/xserver-xorg-img-bxm_1.21.1-2_arm64.deb
```

After booting the image, check `modinfo pvrsrvkm`, `lsmod`, `dmesg` and
`vulkaninfo --summary`. The reported Vulkan device must be the BXM hardware.
A compute dispatch/readback test on the board is required before accepting the
image for GPU workloads; dependency checks during image construction cannot
validate the kernel/firmware handshake or shader execution.
