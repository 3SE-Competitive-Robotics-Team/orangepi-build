#!/usr/bin/env bash
# Run on Linux with the original vendor archive as the sole argument.
set -euo pipefail
repo=$(cd "$(dirname "$0")/../.." && pwd)
package=$(realpath "${1:?Usage: $0 /path/to/xserver-xorg-img-bxm_1.21.1-2_arm64.deb}")
mkdir -p "$repo/output"
fixture=$(mktemp -d "$repo/output/test-powervr.XXXXXX")
trap 'rm -rf "$fixture"' EXIT
SRC=$fixture
EXTER=$fixture/external
SDCARD=$fixture/rootfs
LINUXSOURCEDIR=$fixture/kernel
export BOARDFAMILY=sun60iw2
export BOARD=orangepizero3w
export BRANCH=current
export RELEASE=trixie
export DESKTOP_ENVIRONMENT=
export BUILD_DESKTOP=no
export SELECTED_CONFIGURATION=cli_minimal
header="$LINUXSOURCEDIR/bsp/modules/gpu/img-bxm/linux/rogue_km/include/pvrversion.h"
vendor="$EXTER/cache/sources/sun60iw2_packages/bullseye/xserver/xserver-xorg-img-bxm_1.21.1-2_arm64.deb"
mkdir -p "$(dirname "$header")" "$(dirname "$vendor")" "$SRC/.tmp/gpu_modules_sun60iw2" "$SDCARD/usr/bin"
ln -s "$repo/scripts" "$SRC/scripts"
ln -s "$package" "$vendor"
printf '#define PVRVERSION_MAJ 24U\n#define PVRVERSION_MIN 2U\n#define PVRVERSION_BUILD 6603887\n' > "$header"
printf module > "$SRC/.tmp/gpu_modules_sun60iw2/pvrsrvkm.ko"
printf sentinel > "$SDCARD/usr/bin/Xorg"

# Stub privileged operations; package extraction, file layout and error
# propagation use the production installer and the actual vendor archive.
grab_version() { echo 6.6.98; }
modinfo() { [[ -f $3 ]] && echo "${test_vermagic:-6.6.98-sun60iw2} SMP"; }
depmod() { printf '%s\n' "$*" >> "$fixture/depmod"; }
run_on_sdcard() { printf '%s\n' "$*" >> "$fixture/chroot"; [[ ${fail_chroot:-no} == no ]]; }
enable_extension() { :; }
rsync() { :; }
chroot() { :; }
dpkg_install_debs_chroot() { :; }
install_wiringop() { :; }
exit_with_error() { echo "$*" >&2; return 1; }
# The upstream family configuration uses unset optional build variables.
set +u
# shellcheck source=/dev/null
source "$repo/external/config/sources/families/sun60iw2.conf"

family_tweaks_s
set -u
[[ -f $SDCARD/usr/lib/powervr/libVK_IMG.so ]]
[[ -f $SDCARD/usr/lib/powervr/libpvr_mesa_wsi.so ]]
for library in "$SDCARD/usr/lib/powervr/"*; do
	[[ $(stat -c %u "$library") == "$(id -u)" ]]
	[[ $(stat -c %g "$library") == "$(id -g)" ]]
	[[ $(stat -Lc %a "$library") == 644 ]]
done
[[ -f $SDCARD/lib/firmware/rgx.fw.36.56.104.183 ]]
[[ -f $SDCARD/lib/firmware/rgx.sh.36.56.104.183 ]]
[[ -f $SDCARD/lib/modules/6.6.98-sun60iw2/extra/pvrsrvkm.ko ]]
[[ $(cat "$SDCARD/usr/bin/Xorg") == sentinel ]]
[[ ! -e $SDCARD/usr/local/lib/libvulkan.so.1 ]]
[[ ! -e $SDCARD/etc/environment ]]
grep -q '"library_path": "/usr/lib/powervr/libVK_IMG.so"' "$SDCARD/usr/share/vulkan/icd.d/img_icd.json"
grep -qx pvrsrvkm "$SDCARD/etc/modules-load.d/powervr.conf"
grep -q 'ldconfig' "$fixture/chroot"
grep -q 'ldd' "$fixture/chroot"
echo 'PASS: Trixie CLI installs Vulkan, firmware and autoload without desktop files'

# Exercise the production fetch gate for a clean Trixie build.
fetch_from_repo() { printf '%s\n' "$*" >> "$fixture/fetch"; }
export BUILD_OPT=image
export GITEE_SERVER=no
# shellcheck disable=SC2016 # Match the literal variable in the build script.
fetch_block=$(sed -n '/^\tif \[\[ ${BOARDFAMILY} == "sun60iw2"/,/^\tfi$/p' "$repo/scripts/main.sh")
eval "$fetch_block"
grep -q 'rk-rootfs-build.git.*sun60iw2_packages' "$fixture/fetch"
echo 'PASS: Trixie image fetches vendor packages'

# Explicit conditionals exercise Bash's errexit-disabled call context too.
# shellcheck source=/dev/null
source "$repo/scripts/sun60iw2-gpu.sh"
test_vermagic=5.15.147-sun60iw2
if install_sun60iw2_headless_gpu; then echo 'FAIL: accepted wrong kernel' >&2; exit 1; fi
unset test_vermagic
echo 'PASS: rejects mismatched kernel module'
mv "$SRC/.tmp/gpu_modules_sun60iw2/pvrsrvkm.ko" "$fixture/saved.ko"
if install_sun60iw2_headless_gpu; then echo 'FAIL: accepted missing module' >&2; exit 1; fi
mv "$fixture/saved.ko" "$SRC/.tmp/gpu_modules_sun60iw2/pvrsrvkm.ko"
echo 'PASS: rejects missing module'
sed -i 's/6603887/1/' "$header"
if install_sun60iw2_headless_gpu; then echo 'FAIL: accepted wrong DDK' >&2; exit 1; fi
sed -i 's/BUILD 1/BUILD 6603887/' "$header"
echo 'PASS: rejects mismatched DDK'
fail_chroot=yes
if install_sun60iw2_headless_gpu; then echo 'FAIL: ignored dependency failure' >&2; exit 1; fi
unset fail_chroot
echo 'PASS: propagates dependency installation failure'
rm "$vendor"
printf corrupt > "$vendor"
if install_sun60iw2_headless_gpu; then echo 'FAIL: accepted corrupt archive' >&2; exit 1; fi
echo 'PASS: rejects corrupt archive'
