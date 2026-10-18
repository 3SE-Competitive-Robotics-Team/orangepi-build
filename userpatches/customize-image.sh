#!/bin/bash

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# 3SE fork: 为 Orange Pi Zero 3W 镜像启用 adbd 和 firefly supervisor 开机自启。
# 厂商的 /etc/adb_conf.sh 负责 USB gadget 建链、functionfs 挂载和 adbd 启动，
# 但镜像里没有任何开机调用点，只能登录串口手工执行。这里把它包装成 systemd unit，
# 镜像启动即自动建链。
#
# firefly 的二进制、配置和模型由 `cargo xtask deploy` 写入 /opt/firefly；镜像负责
# 预置并 enable supervisor unit，开机默认启动。
#
# adb 设备序列号由 /etc/firefly/adb-serial 提供（取首行，产线逐台写入）；
# 该文件缺失时 /etc/adb_conf.sh 回落到厂商默认值，所以镜像本身不携带固定序列号。

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

install_firefly_unit() {
	local unit_path=/etc/systemd/system/firefly.service

	# 仅 Zero 3W 需要；其它板子的镜像保持原样
	[[ "$BOARD" == "orangepizero3w" ]] || return 0

	install -m 0644 /tmp/overlay/etc/systemd/system/firefly.service "$unit_path"
	mkdir -p /etc/systemd/system/multi-user.target.wants
	ln -sf "$unit_path" /etc/systemd/system/multi-user.target.wants/firefly.service
}

install_adbd_unit
install_firefly_unit
