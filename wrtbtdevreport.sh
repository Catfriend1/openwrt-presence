#/bin/sh
#
# Info:			OpenWRT Bluetooth Reachable Device Syslog Reporter
# Filename:		wrtbtdevreport.sh
# Usage:		This script gets called by cron every X minutes.
# 				#
#				# Force an immediate report via syslog to the collector server.
#				sh "/root/wrtbtdevreport.sh"
#
# Installation:	
## Remember to fill out your BT device MAC addresses below at BT_DEVICES="...".
#
# chmod +x "/root/wrtbtdevreport.sh"
# LUCI: System / Scheduled Tasks / Add new row
# 	*/1 * * * * /bin/sh "/root/wrtbtdevreport.sh" >/dev/null 2>&1
# Restart Cron:
# 	/etc/init.d/cron restart
#
# Script Configuration
ATTEMPT_USB_POR_ON_HCI_FAIL="0"
HCI_USB_PORT="/sys/class/gpio/tp-link:power:usb2/value"
DEBUG_MODE="0"
LOGFILE="/tmp/wrtbtdevreport.log"
LOG_MAX_LINES="1000"
#
# -----------------------------------------------------
# -------------- START OF FUNCTION BLOCK --------------
# -----------------------------------------------------
logAdd ()
{
	TMP_DATETIME="$(date '+%Y-%m-%d [%H-%M-%S]')"
	TMP_LOGSTREAM="$(tail -n ${LOG_MAX_LINES} ${LOGFILE} 2>/dev/null)"
	echo "${TMP_LOGSTREAM}" > "$LOGFILE"
	if [ "${1}" = "-q" ]; then
		# Quiet mode.
		echo "${TMP_DATETIME} ${@:2}" >> "${LOGFILE}"
	else
		# Loud mode.
		echo "${TMP_DATETIME} $*" | tee -a "${LOGFILE}"
	fi
	return
}

isBluetoothDeviceReachable () {
	#
	# Usage:		isBluetoothDeviceReachable [BT_MAC_ADDR]
	# Called by:	bluetoothScanner
	# Returns:
	# 	0 : If device is reachable and valid
	# 	1 : If device is not reachable or considered invalid
	# Security Note: Reachable does NOT mean authenticated.
	#
	IBDP_HCITOOL_RESULT="$(hcitool info "${1}" 2>/dev/null)"
	if ( ! echo "${IBDP_HCITOOL_RESULT}" | grep -q "${1}" ); then
		return 1
	fi
	#
	return 0
}

dumpLocalReachableBTDevices () {
	#
	# Usage:				dumpLocalReachableBTDevices
	# Returns:				All reachable BT devices are returned as a cumulated result.
	# Example Result:		";hci0,aa:bb:cc:dd:ee:ff|hci0,aa:bb:cc:dd:ff:ee|" (without newline at the end)
	#
	# Called by:	MAIN
	#
	# Consts.
	# 			DEVICE 1				DEVICE 2
	BT_DEVICES="aa:bb:cc:dd:ee:f1 aa:bb:cc:dd:ee:f2"
	BT_IF_NAME="hci0"
	#
	if ( ! hciconfig -a 2>/dev/null | grep -q "${BT_IF_NAME}:" ); then
		logAdd -q "[WARN] dumpLocalReachableBTDevices: Bluetooth support is not available. ${BT_IF_NAME} not found."
		return 1
	fi
	#
	# Clear cache by forcing down before up
	hciconfig -a "${BT_IF_NAME}" down >/dev/null 2>&1
	hciconfig -a "${BT_IF_NAME}" up >/dev/null 2>&1
	if ( ! hciconfig -a ${BT_IF_NAME} 2>/dev/null | grep -q "UP" ); then
		if [ "${ATTEMPT_USB_POR_ON_HCI_FAIL}" = "0" ]; then
			logAdd -q "[ERROR] dumpLocalReachableBTDevices: Bluetooth support is not available. ${BT_IF_NAME} is down."
			return 1
		else
			logAdd -q "[ERROR] dumpLocalReachableBTDevices: Bluetooth support is not available. ${BT_IF_NAME} is down. Attempting USB POR ..."
			echo "0" > "${HCI_USB_PORT}"
			sleep 5
			echo "1" > "${HCI_USB_PORT}"
			sleep 5
			hciconfig -a "${BT_IF_NAME}" up >/dev/null 2>&1
			if ( ! hciconfig -a ${BT_IF_NAME} 2>/dev/null | grep -q "UP" ); then
				logAdd -q "[ERROR] dumpLocalReachableBTDevices: Bluetooth support is not available. USB POR FAILED."
				return 1
			fi
			logAdd -q "[ERROR] dumpLocalReachableBTDevices: Bluetooth support is available again. USB POR succeeded."
			# fallthrough
		fi
	fi
	#
	# Bluetooth adapter is AVAILABLE.
	if ( ! cat /var/lib/bluetooth/*/settings | grep -q "Alias=${HOSTNAME}" ); then
		bluetoothctl system-alias "${HOSTNAME}" >/dev/null 2>&1
	fi
	# 
	for BT_DEVICE_MAC_ADDR in ${BT_DEVICES}; do
		if ( isBluetoothDeviceReachable "${BT_DEVICE_MAC_ADDR}" ); then
			echo -n "${BT_IF_NAME},${BT_DEVICE_MAC_ADDR}|"
		fi
	done 
	#
	return 0
}
# ---------------------------------------------------
# -------------- END OF FUNCTION BLOCK --------------
# ---------------------------------------------------
#
#
# 
# ---------------------------------------------------
# ----------------- SCRIPT MAIN ---------------------
# ---------------------------------------------------
# 
# Write reachable BT device MAC addresses to local syslog.
# If a syslog-ng server is configured in LUCI, the log will be forwarded to it.
logger -t "wrtbtdevreport" "$(echo ";$(dumpLocalReachableBTDevices)")"
#
# For testing purposes only.
## echo ";$(dumpLocalReachableBTDevices)"
#
exit 0
