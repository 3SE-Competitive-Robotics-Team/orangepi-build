#!/usr/bin/env bash

# Install the BXM Vulkan runtime into a headless rootfs. The caller supplies a
# pvrsrvkm module built with this image's kernel and the matching vendor DDK.
install_sun60iw2_headless_gpu() (
	set -euo pipefail
	local package="$EXTER/cache/sources/sun60iw2_packages/bullseye/xserver/xserver-xorg-img-bxm_1.21.1-2_arm64.deb"
	local module="$SRC/.tmp/gpu_modules_sun60iw2/pvrsrvkm.ko"
	local version kernel_release staging library
	version=$(grab_version "$LINUXSOURCEDIR") || exit 1
	kernel_release="$version-$BOARDFAMILY"

	# This archive and the BSP module use DDK 24.2.6603887. Verify the archive
	# before extraction; the desktop bundle also contains unrelated system files.
	echo "c8e606db1abdea40a5b97f7905ea86901b50c5fe1b76a55356ab70dde3304c3a  $package" | sha256sum -c - || exit 1
	[[ $(modinfo -F vermagic "$module") == "$kernel_release "* ]] || exit 1
	grep -Eq '^#define PVRVERSION_MAJ +24U' "$LINUXSOURCEDIR/bsp/modules/gpu/img-bxm/linux/rogue_km/include/pvrversion.h" || exit 1
	grep -Eq '^#define PVRVERSION_MIN +2U' "$LINUXSOURCEDIR/bsp/modules/gpu/img-bxm/linux/rogue_km/include/pvrversion.h" || exit 1
	grep -Eq '^#define PVRVERSION_BUILD +6603887$' "$LINUXSOURCEDIR/bsp/modules/gpu/img-bxm/linux/rogue_km/include/pvrversion.h" || exit 1

	mkdir -p "$SRC/output" || exit 1
	staging=$(mktemp -d "$SRC/output/powervr.XXXXXX") || exit 1
	trap 'rm -rf "$staging"' EXIT
	dpkg-deb -x "$package" "$staging" || exit 1

	# Vulkan's optional WSI library also links XCB libraries, even without an X
	# server. Keep Debian's Vulkan loader, Mesa, Xorg and OpenCL loader intact.
	run_on_sdcard "apt-get -y --no-install-recommends install libvulkan1 vulkan-tools libdrm2 libx11-6 libx11-xcb1 libxcb1 libexpat1 libxcb-dri3-0 libxcb-present0 libxcb-xfixes0 libxcb-sync1 libxcb-randr0 libxcb-shm0 libxshmfence1 libudev1 zlib1g libcap2" || exit 1
	install -d "$SDCARD/usr/lib/powervr" "$SDCARD/lib/firmware" \
		"$SDCARD/etc/ld.so.conf.d" "$SDCARD/etc/modules-load.d" \
		"$SDCARD/usr/share/vulkan/icd.d" "$SDCARD/lib/modules/$kernel_release/extra" || exit 1
	for library in libVK_IMG libsrv_um libusc libufwriter; do
		cp -a "$staging/usr/lib/$library".so* "$SDCARD/usr/lib/powervr/" || exit 1
	done
	install -m 644 "$staging/usr/local/lib/libpvr_mesa_wsi.so" "$SDCARD/usr/lib/powervr/" || exit 1
	install -m 644 "$staging/lib/firmware/rgx.fw.36.56.104.183" \
		"$staging/lib/firmware/rgx.sh.36.56.104.183" "$SDCARD/lib/firmware/" || exit 1
	install -m 644 "$module" "$SDCARD/lib/modules/$kernel_release/extra/pvrsrvkm.ko" || exit 1
	printf '%s\n' /usr/lib/powervr > "$SDCARD/etc/ld.so.conf.d/powervr.conf" || exit 1
	printf '%s\n' pvrsrvkm > "$SDCARD/etc/modules-load.d/powervr.conf" || exit 1
	cat > "$SDCARD/usr/share/vulkan/icd.d/img_icd.json" <<-'ICD' || exit 1
	{
	    "file_format_version": "1.0.0",
	    "ICD": {
	        "library_path": "/usr/lib/powervr/libVK_IMG.so",
	        "api_version": "1.3.277"
	    }
	}
	ICD
	depmod -b "$SDCARD" "$kernel_release" || exit 1
	run_on_sdcard "ldconfig" || exit 1
	# Fail the image build if any runtime dependency is unresolved.
	# shellcheck disable=SC2016 # Expansion happens inside the target rootfs.
	run_on_sdcard 'for library in /usr/lib/powervr/*.so; do result=$(ldd "$library") || exit 1; printf "%s\n" "$result"; case "$result" in *"not found"*) exit 1 ;; esac; done'
)
