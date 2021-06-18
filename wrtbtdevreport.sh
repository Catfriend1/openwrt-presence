#/bin/sh
#
# Info:			OpenWRT Bluetooth Reachable Device Syslog Reporter
# Filename:		wrtbtdevreport.sh
# Usage:		This script gets called by cron every X minutes.
# 				#
#				# Force an immediate report via syslog to the collector server.
#				sh "/root/wrtbtdevreport.sh"
#
# Verified working on hardware:
# 	TP-Link Archer C7v2
# 	TP-Link Archer C7v5
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
ATTEMPT_USB_POR_ON_HCI_FAIL="1"
HCI_USB_PORT="/sys/class/gpio/tp-link:power:usbX/value"
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

checkPrerequisites () {
	#
	# Usage:				checkPrerequisites
	# Purpose:				Checks if bluetooth hardware is present at boot time and backs off if not.
	# Returns:
	# 	[GVAR]	HCI_USB_PORT_NR
	#
	# Called by:	MAIN
	#
	if [ -f "/tmp/bt-hardware.info" ]; then
		HCI_USB_PORT_NR="$(cat "/tmp/bt-hardware.info" 2>/dev/null)"
		HCI_USB_PORT="/sys/class/gpio/tp-link:power:usb${HCI_USB_PORT_NR}/value"
		echo "[DEBUG] checkPrerequisites: Remembered discovered bt hardware on USB port ${HCI_USB_PORT_NR}."
		return 0
	fi
	#
	VENDOR_ID_BROADCOM="0a5c"
	for usbPortProbe in $(ls -1 "/sys/class/gpio/" | grep "^tp-link:power:usb" | sed "s/.*usb//") 3 2; do
		if ( ! cat "/sys/bus/usb/devices/usb${usbPortProbe}/${usbPortProbe}-1/idVendor" 2>/dev/null | grep -q "^${VENDOR_ID_BROADCOM}" ); then
			continue
		fi
		#
		# /sys/class/gpio/tp-link:power:usb1 corresponds to usbPortProbe == 2.
		case ${usbPortProbe} in 
			'1')
				usbPortProbe="2"
				;;
			'2')
				usbPortProbe="1"
				;;
		esac
		#
		logAdd "[INFO] checkPrerequisites: Discovered bt hardware on USB port ${usbPortProbe}."
		echo "${usbPortProbe}" > "/tmp/bt-hardware.info"
		HCI_USB_PORT="/sys/class/gpio/tp-link:power:usb${usbPortProbe}/value"
		if [ ! -f "${HCI_USB_PORT}" ]; then
			echo "[ERROR] checkPrerequisites: Missing [${HCI_USB_PORT}]."
			return 99
		fi
		return 0
	done
	echo "[ERROR] Failed to discover bt hardware."
	return 99
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
	if ( logread -l 3 | grep -q "\(kern.err\|${HOSTNAME}\) kernel.*Bluetooth: hci." ); then
		if ( ! tryUSBPOR "${BT_IF_NAME}" "${HCI_USB_PORT}" ); then
			return 1
		fi
	fi
	#
	if ( ! hciconfig -a 2>/dev/null | grep -q "${BT_IF_NAME}:" ); then
		if ( ! tryUSBPOR "${BT_IF_NAME}" "${HCI_USB_PORT}" ); then
			return 1
		fi
	fi
	#
	# Clear cache by forcing down before up
	hciconfig -a "${BT_IF_NAME}" down >/dev/null 2>&1
	hciconfig -a "${BT_IF_NAME}" up >/dev/null 2>&1
	if ( ! hciconfig -a "${BT_IF_NAME}" 2>/dev/null | grep -q "UP" ); then
		if ( ! tryUSBPOR "${BT_IF_NAME}" "${HCI_USB_PORT}" ); then
			return 1
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


tryUSBPOR () {
	#
	# Usage:				tryUSBPOR "[HCI_IF_NAME]" "[HCI_USB_PORT]"
	# Example:				tryUSBPOR "hci0" "/sys/class/gpio/tp-link:power:usb2/value"
	#
	# Called By:
	# 	dumpLocalReachableBTDevices
	#
	# Global Variables.
	# 	[IN] ATTEMPT_USB_POR_ON_HCI_FAIL
	#
	# Variables.
	TMP_TUP_HCI_IF_NAME="${1}"
	TMP_TUP_HCI_USB_PORT="${2}"
	#
	if [ "${ATTEMPT_USB_POR_ON_HCI_FAIL}" = "0" ]; then
		if ( ! hciconfig -a 2>/dev/null | grep -q "${TMP_TUP_HCI_IF_NAME}:" ); then
			logAdd -q "[WARN] tryUSBPOR: Bluetooth support is not available. ${TMP_TUP_HCI_IF_NAME} not found."
			return 1
		elif ( ! hciconfig -a "${TMP_TUP_HCI_IF_NAME}" 2>/dev/null | grep -q "UP" ); then
			logAdd -q "[ERROR] tryUSBPOR: Bluetooth support is not available. ${TMP_TUP_HCI_IF_NAME} is down."
			return 1
		fi
		logAdd -q "[ERROR] tryUSBPOR: Bluetooth support is not available. ${TMP_TUP_HCI_IF_NAME} failed, unknown reason."
		return 1
	fi
	#
	logAdd -q "[WARN] tryUSBPOR: Bluetooth support is not available. ${TMP_TUP_HCI_IF_NAME} FAILED. Attempting USB POR ..."
	echo "0" > "${TMP_TUP_HCI_USB_PORT}"
	sleep 5
	echo "1" > "${TMP_TUP_HCI_USB_PORT}"
	sleep 5
	hciconfig -a "${TMP_TUP_HCI_IF_NAME}" up >/dev/null 2>&1
	if ( ! hciconfig -a ${TMP_TUP_HCI_IF_NAME} 2>/dev/null | grep -q "UP" ); then
		logAdd -q "[ERROR] tryUSBPOR: Bluetooth support is not available. USB POR FAILED."
		return 1
	fi
	logAdd -q "[INFO] tryUSBPOR: Bluetooth support is available again. USB POR succeeded."
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
checkPrerequisites
if [ "$?" -ne 0 ]; then
	exit $?
fi
# 
# Write reachable BT device MAC addresses to local syslog.
# If a syslog-ng server is configured in LUCI, the log will be forwarded to it.
logger -t "wrtbtdevreport" "$(echo ";$(dumpLocalReachableBTDevices)")"
#
# For testing purposes only.
## echo ";$(dumpLocalReachableBTDevices)"
#
exit 0
