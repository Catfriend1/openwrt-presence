#!/bin/sh
#
#####################
# FUNCTIONS START	#
#####################
installPrequisites () {
	# apt-get update
	# apt-get install -y build-essential libncurses5-dev libncursesw5-dev zlib1g-dev gawk git gettext libssl-dev xsltproc rsync wget unzip python
	#
	# Download Imagebuilder.
	mkdir -p /root/install/
	cd /root/install/
	#
	SNAPSHOT_IMAGEBUILDER="https://downloads.openwrt.org/snapshots/targets/ath79/generic/openwrt-imagebuilder-ath79-generic.Linux-x86_64.tar.xz"
	OPENWRT_VERSION="21.02.0-rc4"
	RELEASE_IMAGEBUILDER_FILENAME="openwrt-imagebuilder-${OPENWRT_VERSION}-ath79-generic.Linux-x86_64.tar.xz"
	if [ ! -f "/root/install/${RELEASE_IMAGEBUILDER_FILENAME}" ]; then
		wget -P /root/install/ "https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/ath79/generic/${RELEASE_IMAGEBUILDER_FILENAME}"
		tar xJf "/root/install/${RELEASE_IMAGEBUILDER_FILENAME}" -C /root/
	fi
	return 0
}


generatePackageList () {
	# Syntax:
	#	generatePackageList
	#
	# Consts
	INSTALL_BATMANADV="1"
	INSTALL_BT="0"
	INSTALL_OPENVPN="0"
	INSTALL_RELAYD="0"
	INSTALL_WIFI_NON_CT_DRIVERS="1"
	REPLACE_LOGD_BY_SYSLOG_NG="0"
	#
	# Variables
	PKG_TO_INSTALL=""
	PKG_TO_REMOVE=""
	#
	# Add packages to the install and remove queue.
	PKG_TO_REMOVE="${PKG_TO_REMOVE} -wpad-basic-wolfssl"
	PKG_TO_INSTALL="${PKG_TO_INSTALL} wpad-mesh-wolfssl"
	#
	# Replace ct with non-ct drivers
	if [ "${INSTALL_WIFI_NON_CT_DRIVERS}" = "1" ]; then
		# Remove order is important
		PKG_TO_REMOVE="${PKG_TO_REMOVE} -kmod-ath10k-ct -ath10k-firmware-qca988x-ct"
		PKG_TO_INSTALL="${PKG_TO_INSTALL} ath10k-firmware-qca988x kmod-ath10k"
	fi
	#
	# batman-adv
	if [ "${INSTALL_BATMANADV}" = "1" ]; then
		PKG_TO_INSTALL="${PKG_TO_INSTALL} batctl-full kmod-batman-adv"
	fi
	#
	# Base system
	PKG_TO_INSTALL="${PKG_TO_INSTALL} bash curl htop logrotate lua luafilesystem luci mailsend terminfo tcpdump"
	#
	# FTP service
	PKG_TO_INSTALL="${PKG_TO_INSTALL} vsftpd"
	#
	# BT
	if [ "${INSTALL_BT}" = "1" ]; then
		PKG_TO_INSTALL="${PKG_TO_INSTALL} bluez-daemon bluez-libs bluez-utils dbus kmod-bluetooth"
	fi
	#
	# Relayd
	if [ "${INSTALL_RELAYD}" = "1" ]; then
		PKG_TO_INSTALL="${PKG_TO_INSTALL} luci-proto-relay relayd"
	fi
	#
	# OpenVPN
	if [ "${INSTALL_OPENVPN}" = "1" ]; then
		PKG_TO_INSTALL="${PKG_TO_INSTALL} luci-app-openvpn openvpn-easy-rsa openvpn-openssl"
	fi
	#
	# Syslog-ng, logd
	if [ "${REPLACE_LOGD_BY_SYSLOG_NG}" = "1" ]; then
		PKG_TO_REMOVE="${PKG_TO_REMOVE} -logd"
		PKG_TO_INSTALL="${PKG_TO_INSTALL} syslog-ng"
	else
		PKG_TO_REMOVE="${PKG_TO_REMOVE} -syslog-ng"
		PKG_TO_INSTALL="${PKG_TO_INSTALL} logd"
	fi
	#
	# USB storage drivers
	PKG_TO_INSTALL="${PKG_TO_INSTALL} block-mount e2fsprogs kmod-fs-ext4 kmod-fs-msdos kmod-scsi-core kmod-usb-storage"
	#
	echo "${PKG_TO_REMOVE} ${PKG_TO_INSTALL}"
	return 0
}
#####################
# FUNCTIONS END		#
#####################
#
installPrequisites
#
# Generate package list.
PACKAGE_LIST="$(generatePackageList)"
echo "[INFO] PACKAGE_LIST=[${PACKAGE_LIST}]"
#
# Build image.
WORKDIR="$(find /root/ -maxdepth 1 -type d -name "openwrt-imagebuilder*" | head -1)"
echo "[INFO] WORKDIR=${WORKDIR}"
cd "${WORKDIR}"
echo "[INFO] --- Press any key to continue ---"
read -r 1 2>/dev/null
echo ""
# make info | grep tplink
# make clean
#
make image FILES="/root/openwrt/imagebuilder-files/" PROFILE="tplink_archer-c7-v2" PACKAGES="${PACKAGE_LIST}"
make image FILES="/root/openwrt/imagebuilder-files/" PROFILE="tplink_archer-c7-v5" PACKAGES="${PACKAGE_LIST}"
#
ls -al /root/openwrt-imagebuilder*/bin/targets/ath79/generic/*.bin
#
exit 0
