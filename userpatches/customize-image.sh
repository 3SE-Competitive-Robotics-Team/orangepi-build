#!/bin/bash

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# 3SE fork: 为 Orange Pi Zero 3W 镜像启用 adbd 开机自启。
# 厂商的 /etc/adb_conf.sh 负责 USB gadget 建链、functionfs 挂载和 adbd 启动，
# 但镜像里没有任何开机调用点，只能登录串口手工执行。这里把它包装成 systemd unit，
# 镜像启动即自动建链。

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4

install_adbd_unit() {
	local unit_path=/etc/systemd/system/adbd.service

	# 仅 Zero 3W 需要；其它板子的镜像保持原样
	[[ "$BOARD" == "orangepizero3w" ]] || return 0

	# adb_conf.sh 由 BSP 包安装；缺失时说明镜像不是预期的组合，留给镜像自身报错
	if [[ ! -x /etc/adb_conf.sh ]]; then
		echo "adbd: /etc/adb_conf.sh missing on $BOARD, skip unit install" >&2
		return 1
	fi

	install -m 0644 /tmp/overlay/etc/systemd/system/adbd.service "$unit_path"
	mkdir -p /etc/systemd/system/multi-user.target.wants
	ln -sf "$unit_path" /etc/systemd/system/multi-user.target.wants/adbd.service
}

install_adbd_unit
