#/bin/bash
trap "" SIGHUP
#
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT
#
# set +m
#
# Filename:			wrtpresence_main.sh
# Usage:			Instanced by service wrapper.
# Purpose:			Tracks STA client associations across a WiFi backed by multiple APs.
# 
# Installation:
# 
# 	Generic advice:
# 		LUCI / System / System / Hostname
# 			Set hostname to "WifiAP-[01|02|03|..]" or adjust the variable to match your hostname convention.
# 				LOGREAD_SOURCE_PREFIX="WifiAP-.."
# 
# 	=========================
# 	== MASTER ACCESS POINT ==
# 	=========================
# 		... where this script is executed.
# 	opkg update
# 	opkg install bash
# 	opkg remove logd
# 	opkg install syslog-ng
# 	chmod +x "/root/wrtpresence"
# 	chmod +x "/root/wrtpresence_main.sh"
# 
# 	LUCI / System / Startup / Local Startup
# 		# sh /root/wrtpresence start
# 
# 	LUCI / System / System / Logging
# 		External system log server
# 			127.0.0.1
# 		Cron Log Level
# 			Warning
# 
# 	chmod +x "/root/wrtwifistareport.sh"
# 	LUCI: System / Scheduled Tasks / Add new row
# 		*/5 * * * * /bin/sh "/root/wrtwifistareport.sh" >/dev/null 2>&1
# 	Restart Cron:
# 		/etc/init.d/cron restart
#
# 	chmod +x "/root/wrtbtdevreport.sh"
# 	LUCI: System / Scheduled Tasks / Add new row
# 		*/1 * * * * /bin/sh "/root/wrtbtdevreport.sh" >/dev/null 2>&1
# 	Restart Cron:
# 		/etc/init.d/cron restart
# 
# 	========================
# 	== SLAVE ACCESS POINT ==
# 	========================
# 		... where WiFi STA clients may roam to/from.
# 	LUCI / System / System / Logging
# 		External system log server
# 			[IP_ADDRESS_OF_MASTER_ACCESS_POINT]
# 		Cron Log Level
# 			Warning
# 
# 	chmod +x "/root/wrtwifistareport.sh"
# 	LUCI: System / Scheduled Tasks / Add new row
# 		*/5 * * * * /bin/sh "/root/wrtwifistareport.sh" >/dev/null 2>&1
# 	Restart Cron:
# 		/etc/init.d/cron restart	
#
# Diagnostics:
#	Cleanup, Reset:
#		sh /root/wrtpresence clean
#	Logging and Monitoring:
#		sh /root/wrtpresence debug	
#		sh /root/wrtpresence showlog
#		sh /root/wrtpresence livelog
# 		sh /root/wrtpresence livestate
# 		sh /root/wrtpresence showstate
#
# Prerequisites:
# 	Configuration
#		LUCI / System /System / Logging
# 			External system log server
# 				127.0.0.1
# 		/etc/config/system
# 			option log_ip '127.0.0.1'
#	Files 
# 		wrtpresence								main service wrapper
# 		wrtpresence_main.sh						main service program
# 		wrtwifistareport.sh						cron job script for sync in case events got lost during reboot
# 		wrtbtdevreport.sh						cron job script for bluetooth scans
# 	Packages
# 		bash									required for arrays
# 		syslog-ng								required for log collection from other APs
# 
#
# FIFO output line examples:
# 	"G/CONSOLIDATED_PRESENCE_STATE=away"
# 	"G/CONSOLIDATED_PRESENCE_STATE=present"
# 	"DEV/[DEVICE_NAME]=away"
# 	"DEV/[DEVICE_NAME]=present"
# 	
#
# For testing purposes only:
# 	killall logread; killall tail; sh wrtpresence stop; bash wrtpresence_main.sh debug
# 	kill -INT "$(cat "/tmp/wrtpresence_main.sh.pid")"
# 
#
# ====================
# Device Configuration
# ====================
#
# 0: 
DEVICE_NAME[0]="Test-Mobile-1"
DEVICE_MAC[0]="aa:bb:cc:dd:ee:ff"
#
# 1: 
DEVICE_NAME[1]="Test-Mobile-2"
DEVICE_MAC[1]="aa:bb:cc:dd:ff:ee"
#
#
# ====================
# Script Configuration
# ====================
PATH=/usr/bin:/usr/sbin:/sbin:/bin
# CURRENT_SCRIPT_PATH="$(cd "$(dirname "$0")"; pwd)"
EVENT_FIFO=/tmp/"$(basename "$0")".event_fifo
PID_FILE=/tmp/"$(basename "$0")".pid
LOGFILE="/tmp/wrtpresence.log"
LOG_MAX_LINES="1000"
DEBUG_MODE="0"
REPORT_CONSOLIDATED_PRESENCE_TO_FIFO="0"
#
# External script FIFOs.
GASERVICE_FIFO="/tmp/wrtgaservice_main.sh.event_fifo"
#
# Internal script DTOs.
ASSOCIATIONS_DTO="/tmp/associations.dto"
#
# External script DTOs.
PRESENT_DEVICES_DTO="/tmp/present_devices.dto"
#
# Timing Configuration.
IDXBUMP_SLEEP_SECONDS="60"
DEVICE_DISCONNECTED_IDX="10"
#
# Optional: Enable wrtwifistareport wifi reports by the local device
CONFIG_WIFI_STA_REPORTS_ENABLED="1"
#
# Optional: Enable wrtbtdevreport bluetooth reports by the local device
CONFIG_BLUETOOTH_REPORTS_ENABLED="0"
#
# -----------------------
# --- Function Import ---
# -----------------------
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

fifoOut ()
{
	if [ "${DEBUG_MODE}" = "1" ]; then
		logAdd -q "[DEBUG] Skipping FIFO-OUT [$1]"
		return 0
	fi
	#
	fifoOut_do "${GASERVICE_FIFO}" "$1"
}

fifoOut_do ()
{
	#
	# Usage:		fifoOut_do [FIFO_FULLFN] [TEXT_CONTENT_WITHOUT_SPACES]
	#
	if [ ! -e "$1" ]; then
		logAdd -q "[ERROR] FIFO does not exist for FIFO-OUT [$2] to $1"
		return
	fi
	logAdd -q "[INFO] FIFO-OUT [$2] to $1"
	( echo "$2" >> "$1" ) &
}

plCheckDevicesByCounters() {
	#
	# Usage:			plCheckDevicesByCounters
	# Example:			plCheckDevicesByCounters
	# Called by:		plAddClient, disconnectIdxBumper
	# Returns:			< nothing >
	#
	# Global Variables.
	# 	[IN] ASSOCIATIONS_DTO
	#
	# Variables.
	DPTE_DEVICE_COUNT="${#DEVICE_MAC[*]}"
	#
	# For testing purposes only.
	# logAdd -q "plCheckDevicesByCounters: triggered"
	# 
	touch "${PRESENT_DEVICES_DTO}"
	touch "${PRESENT_DEVICES_DTO}.new"
	# 
	# Loop through configured DEVICE ARRAY.
	DPTE_DEVICE_I="0"
	while (true); do
		#
		# Are we done yet?
		#
		if [ ${DPTE_DEVICE_I} -eq ${DPTE_DEVICE_COUNT} ]; then
			break;
		fi
		#
		if (cat "${ASSOCIATIONS_DTO}" 2> /dev/null | grep -Fi "=${DEVICE_MAC[${DPTE_DEVICE_I}]}=" | grep -vq "=${DEVICE_DISCONNECTED_IDX}$"); then
			# 
			# Device PRESENT.
			echo "${DEVICE_NAME[${DPTE_DEVICE_I}]}" >> "${PRESENT_DEVICES_DTO}.new"
			# 
			# Did the device state change from AWAY to PRESENT?
			if ( ! grep -iq "${DEVICE_NAME[${DPTE_DEVICE_I}]}$" "${PRESENT_DEVICES_DTO}" ); then
				#
				# DEVICE_ACTION_PRESENT.
				#
				fifoOut "DEV/${DEVICE_NAME[${DPTE_DEVICE_I}]}=present"
				#
			fi
		else
			# 
			# Device AWAY.
			# 
			# Did the device state change from PRESENT to AWAY?
			if ( grep -iq "${DEVICE_NAME[${DPTE_DEVICE_I}]}$" "${PRESENT_DEVICES_DTO}" ); then
				#
				# DEVICE_ACTION_AWAY.
				# 
				fifoOut "DEV/${DEVICE_NAME[${DPTE_DEVICE_I}]}=away"
				#
			fi
		fi
		#
		# Continue with next device.
		DPTE_DEVICE_I="$((DPTE_DEVICE_I+1))"
		#
	done
	# 
	if [ "${REPORT_CONSOLIDATED_PRESENCE_TO_FIFO}" == "1" ]; then
		# Did the consolidated presence state change?
		if [ -s "${PRESENT_DEVICES_DTO}.new" ]; then
			# New state: CONSOLIDATED_DEVICE_STATE=PRESENT
			if [ ! -s "${PRESENT_DEVICES_DTO}" ]; then
				# Previous state: CONSOLIDATED_DEVICE_STATE=AWAY
				logAdd -q "[INFO] CONSOLIDATED_PRESENCE_STATE=present"
				fifoOut "G/CONSOLIDATED_PRESENCE_STATE=present"
			fi
		else
			# New state: CONSOLIDATED_DEVICE_STATE=AWAY
			if [ -s "${PRESENT_DEVICES_DTO}" ]; then
				# Previous state: CONSOLIDATED_DEVICE_STATE=PRESENT
				logAdd -q "[INFO] CONSOLIDATED_PRESENCE_STATE=away"
				fifoOut "G/CONSOLIDATED_PRESENCE_STATE=away"
			fi
		fi
	fi
	# 
	# Overwrite last state with new state.
	mv "${PRESENT_DEVICES_DTO}.new" "${PRESENT_DEVICES_DTO}"
	#
	return
}

plAddClient() {
	#
	# Usage:			plAddClient [STATION_NAME] [CLIENT_MAC_ADDR] [TEXT_REASON]
	# Example:			plAddClient "WifiAP-01_wlan0-4" "aa:bb:cc:dd:ee:ff" "AP-STA-CONNECTED"
	# Called by:		logreader
	# Returns:			< nothing >
	#
	# Global Variables.
	# 	[IN] ASSOCIATIONS_DTO
	#
	# Variables.
	TMP_PLAC_STATION_NAME="${1}"
	TMP_PLAC_MAC_ADDR="${2}"
	TMP_PLAC_TEXT_REASON="${3}"
	# 
	if [ ! -f "${ASSOCIATIONS_DTO}" ]; then
		touch "${ASSOCIATIONS_DTO}"
	fi
	# 
	if ( ! grep -F -q -i "${TMP_PLAC_STATION_NAME}=${TMP_PLAC_MAC_ADDR}=" "${ASSOCIATIONS_DTO}" ); then
		logAdd -q "plAddClient: ${TMP_PLAC_STATION_NAME} +${TMP_PLAC_MAC_ADDR} reason: ${TMP_PLAC_TEXT_REASON}"
		# "=0" means connected.
		echo "${TMP_PLAC_STATION_NAME}=${TMP_PLAC_MAC_ADDR}=0" >> "${ASSOCIATIONS_DTO}"
		cat "${ASSOCIATIONS_DTO}" 2>/dev/null | sort > "${ASSOCIATIONS_DTO}.tmp"
		mv "${ASSOCIATIONS_DTO}.tmp" "${ASSOCIATIONS_DTO}"
	else
		logAdd -q "plAddClient: ${TMP_PLAC_STATION_NAME} ${TMP_PLAC_MAC_ADDR}=0 reason: ${TMP_PLAC_TEXT_REASON}"
		sed -i "s/^${TMP_PLAC_STATION_NAME}\=${TMP_PLAC_MAC_ADDR}\=.*$/${TMP_PLAC_STATION_NAME}\=${TMP_PLAC_MAC_ADDR}\=0/gI" "${ASSOCIATIONS_DTO}"
	fi
	# 
	plCheckDevicesByCounters
	#
	return
}

plMarkClientAsDisconnected() {
	#
	# Usage:			plMarkClientAsDisconnected [STATION_NAME] [CLIENT_MAC_ADDR] [TEXT_REASON]
	# Example:			plMarkClientAsDisconnected "WifiAP-01" "aa:bb:cc:dd:ee:ff" "AP-STA-DISCONNECTED"
	# Called by:		logreader
	# Returns:			< nothing >
	#
	# Global Variables.
	# 	[IN] ASSOCIATIONS_DTO
	#
	# Variables.
	TMP_PLAC_STATION_NAME="${1}"
	TMP_PLAC_MAC_ADDR="${2}"
	TMP_PLAC_TEXT_REASON="${3}"
	# 
	if [ ! -f "${ASSOCIATIONS_DTO}" ]; then
		touch "${ASSOCIATIONS_DTO}"
	fi
	# 
	if ( grep -F -q -i "${TMP_PLAC_STATION_NAME}=${TMP_PLAC_MAC_ADDR}=" "${ASSOCIATIONS_DTO}" ); then
		logAdd -q "plMarkClientAsDisconnected: ${TMP_PLAC_STATION_NAME} -${TMP_PLAC_MAC_ADDR} reason: ${TMP_PLAC_TEXT_REASON}"
		# ">0" means disconnected.
		sed -i "s/${TMP_PLAC_STATION_NAME}\=${TMP_PLAC_MAC_ADDR}\=0/${TMP_PLAC_STATION_NAME}\=${TMP_PLAC_MAC_ADDR}\=1/gI" "${ASSOCIATIONS_DTO}"
	else
		logAdd -q "plMarkClientAsDisconnected: ${TMP_PLAC_STATION_NAME} -${TMP_PLAC_MAC_ADDR} reason: ${TMP_PLAC_TEXT_REASON} - Skipping, client not present in DTO."
	fi
	#
	return
}

plRemoveClient() {
	#
	# Usage:			plRemoveClient [STATION_NAME] [CLIENT_MAC_ADDR]
	# Example:			plRemoveClient "WifiAP-01" "aa:bb:cc:dd:ee:ff"
	# Called by:		-
	# Returns:			< nothing >
	#
	# Global Variables.
	# 	[IN] ASSOCIATIONS_DTO
	#
	# Variables.
	TMP_PLAC_STATION_NAME="${1}"
	TMP_PLAC_MAC_ADDR="${2}"
	# 
	if [ ! -f "${ASSOCIATIONS_DTO}" ]; then
		touch "${ASSOCIATIONS_DTO}"
	fi
	# 
	if ( grep -F -q -i "${TMP_PLAC_STATION_NAME}=${TMP_PLAC_MAC_ADDR}=" "${ASSOCIATIONS_DTO}" ); then
		logAdd -q "plRemoveClient: ${TMP_PLAC_STATION_NAME} -${TMP_PLAC_MAC_ADDR}"
		sed -i "/^${TMP_PLAC_STATION_NAME}\=${TMP_PLAC_MAC_ADDR}\=.*$/d" "${ASSOCIATIONS_DTO}"
	else
		logAdd -q "plRemoveClient: ${TMP_PLAC_STATION_NAME} -${TMP_PLAC_MAC_ADDR} - Skipping, client not present in DTO."
	fi
	#
	return
}

logreader() {
	#
	# Called by:	MAIN
	#
	# Global Variables.
	# 	[IN] ASSOCIATIONS_DTO
	# 
	logAdd -q "[INFO] BEGIN logreader"
	#
	LOGREAD_BIN="$(which logread)"
	if ( opkg list "syslog-ng" | grep -q "syslog-ng" ); then
		# logread is provided by package "syslog-ng"
		LOGREAD_SOURCE_PREFIX="WifiAP-.."
	else
		# logread is provided by default package "logd"
		LOGREAD_SOURCE_PREFIX="daemon\.notice"
	fi
	#
	if [ ! -f "/var/log/messages" ]; then
		logAdd -q "[INFO] logreader: Waiting for /var/log/messages"
	fi
	while [ ! -f "/var/log/messages" ]; do
		sleep 2
	done
	logAdd -q "[INFO] BEGIN logreader_loop"
	${LOGREAD_BIN} -f | while read line; do
		if $(echo -n "${line}" | grep -q "${LOGREAD_SOURCE_PREFIX}.*hostapd.*\(AP-STA-CONNECTED\|AP-STA-DISCONNECTED\)"); then
			if $(echo -n "${line}" | grep -q "AP-STA-CONNECTED"); then
				STATION_NAME="$(echo -n "${line}" | grep -o "${LOGREAD_SOURCE_PREFIX}")"
				WIFI_IF_NAME="$(echo -n "${line}" | grep -o -E "(wlan|phy)[[:xdigit:]]{1}(-(ap)?[[:xdigit:]]{1,})?")"
				MAC_ADDR="$(echo -n "${line}" | grep -o -E "([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}")"
				# fifoOut_do "${EVENT_FIFO}" "CONNECT: ${MAC_ADDR} on ${STATION_NAME}"
				plAddClient "${STATION_NAME}_${WIFI_IF_NAME}" "${MAC_ADDR}" "AP-STA-CONNECTED"
			elif $(echo -n "${line}" | grep -q "AP-STA-DISCONNECTED"); then
				STATION_NAME="$(echo -n "${line}" | grep -o "${LOGREAD_SOURCE_PREFIX}")"
				WIFI_IF_NAME="$(echo -n "${line}" | grep -o -E "(wlan|phy)[[:xdigit:]]{1}(-(ap)?[[:xdigit:]]{1,})?")"
				MAC_ADDR="$(echo -n "${line}" | grep -o -E "([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}")"
				# fifoOut_do "${EVENT_FIFO}" "DISCONNECT: ${MAC_ADDR} on ${STATION_NAME}"
				plMarkClientAsDisconnected "${STATION_NAME}_${WIFI_IF_NAME}" "${MAC_ADDR}" "AP-STA-DISCONNECTED"
			fi
		elif $(echo -n "${line}" | grep -q "${LOGREAD_SOURCE_PREFIX}.*\(wrtbtdevreport\|wrtwifistareport\): ;.*"); then
			STATION_NAME="$(echo -n "${line}" | grep -o "${LOGREAD_SOURCE_PREFIX}" | head -n 1)"
			WIFI_STA_LIST="$(echo -n "${line}" | cut -d ";" -f 2)"
			#
			# Sanity check to filter wrongly formatted log messages.
			if [ ! ";${WIFI_STA_LIST}" = "$(echo ";${WIFI_STA_LIST}" | grep -o -E ";(([a-zA-z0-9,:-]*\|){1,})?")" ]; then
				logAdd -q "logreader: Ignored invalid report from device [${STATION_NAME}]."
				continue
			fi
			#
			REPORT_TYPE="wrtwifistareport"
			if $(echo -n "${line}" | grep -q "${LOGREAD_SOURCE_PREFIX}.*wrtbtdevreport: ;.*"); then
				REPORT_TYPE="wrtbtdevreport"
			fi
			#
			# For testing purposes only.
			## logAdd -q "logreader: Got raw line [${line}]"
			## logAdd -q "logreader: Got ${REPORT_TYPE}: [${WIFI_STA_LIST}] on [${STATION_NAME}]"
			#
			# We store the current unix timestamp for this access point as the time when we received its
			# last report. If the AP "dies", we can detect it later and remove its STA clients from
			# ASSOCIATIONS_DTO.
			echo "$(date +%s)" > "/tmp/${STATION_NAME}.last_wrtwifistareport"
			# 
			# We need to update our associations cache according to the full report of active STA clients
			# for the given STATION_NAME.
			if [ ! -f "${ASSOCIATIONS_DTO}" ]; then
				touch "${ASSOCIATIONS_DTO}"
			fi
			# 
			# Step 1: Check for associations we did not know they were active.
			echo -e "$(echo "${WIFI_STA_LIST}" | sed -r -e "s/\|/\\\n/g")" | while read wifiif_macaddr; do
				if [ ! -z "${wifiif_macaddr}" ]; then
					WIFI_IF_NAME="$(echo "${wifiif_macaddr}" | cut -d "," -f 1)"
					MAC_ADDR="$(echo "${wifiif_macaddr}" | cut -d "," -f 2)"
					#
					# For testing purposes only.
					## logAdd -q "logreader: ${REPORT_TYPE}[1]: ... macaddr=[${MAC_ADDR}] on wifiif=[${WIFI_IF_NAME}]"
					## logger -t "wrtbtdevreport" ";hci0,aa:bb:cc:dd:ee:ff|"
					#
					# MAC address already in DTO?
					if ( ! grep -q -i "^${STATION_NAME}_${WIFI_IF_NAME}=${MAC_ADDR}=0$" "${ASSOCIATIONS_DTO}" ); then
						# logAdd -q "logreader: ${REPORT_TYPE}: MAC [${MAC_ADDR}] missing - Adding."
						plAddClient "${STATION_NAME}_${WIFI_IF_NAME}" "${MAC_ADDR}" "${REPORT_TYPE}"
					fi
				fi
			done
			#
			# Step 2: Check for associations we still know but they are outdated because of missed
			# disconnect events.
			cat "${ASSOCIATIONS_DTO}" 2>/dev/null | grep "^${STATION_NAME}_" | grep "=0$" | while read line; do
				if [ ! -z "${line}" ]; then
					WIFI_IF_NAME="$(echo "${line}" | cut -d "=" -f 1 | cut -d "_" -f 2)"
					MAC_ADDR="$(echo "${line}" | cut -d "=" -f 2)"
					#
					# For testing purposes only.
					# logAdd -q "logreader: ${REPORT_TYPE}[2]: ... macaddr=[${MAC_ADDR}] on wifiif=[${WIFI_IF_NAME}]"
					#
					# For testing purposes only.
					# 	logger -t "wrtbtdevreport" ";"
					# 	logger -t "wrtwifistareport" ";"
					#
					if [ "${REPORT_TYPE}" = "wrtwifistareport" ]; then
						if ( echo "${WIFI_IF_NAME}" | grep -q "hci.*" ); then
							# Skip bluetooth devices as they are not contained in wrtwifistareport messages.
							continue
						fi
					else
						if ( echo "${WIFI_IF_NAME}" | grep -q  "wlan\|phy.*" ); then
							# Skip WiFi devices as they are not contained in wrtbtdevreport messages.
							continue
						fi
					fi
					# 
					if ( ! echo -e "$(echo "${WIFI_STA_LIST}" | sed -r -e "s/\|/\\\n/g")" | grep -i -q "^${WIFI_IF_NAME},${MAC_ADDR}$" ); then
						# logAdd -q "logreader: ${REPORT_TYPE}: MAC [${MAC_ADDR}] no longer associated - Marking as disconnected."
						plMarkClientAsDisconnected "${STATION_NAME}_${WIFI_IF_NAME}" "${MAC_ADDR}" "${REPORT_TYPE}"
					fi
					# 
				fi
			done
			#
		elif $(echo -n "${line}" | grep -q "${LOGREAD_SOURCE_PREFIX}.*procd: - init complete -"); then
			STATION_NAME="$(echo -n "${line}" | grep -o "${LOGREAD_SOURCE_PREFIX}" | head -n 1)"
			logAdd -q "logreader: Detected reboot of device [${STATION_NAME}]."
			# STN_DISABLE_NOTIFICATION="1"
			# sendTelegramNotification "${HOSTNAME}: Detected reboot of device [${STATION_NAME}]." ""
		fi
	done
}

disconnectIdxBumper() {
	#
	# Called by:	MAIN
	#
	# Global Variables.
	# 	[IN] ASSOCIATIONS_DTO
	# 
	# Variables.
	LOOP_CNT=0
	logAdd -q "[INFO] BEGIN disconnectIdxBumper_loop"
	while true
	do
		LOOP_CNT="$((LOOP_CNT+1))"
		# echo "${LOOP_CNT}" >> "${EVENT_FIFO}"
		# logAdd -q "disconnectIdxBumper: LOOP_CNT=[${LOOP_CNT}]"
		#
		# TASK 1
		# Increment counter value for every disconnected STA MAC.
		# Only grab rows from disconnected devices.
		cat "${ASSOCIATIONS_DTO}" 2>/dev/null | grep -v "=0$" | while read line; do
			# 
			# Get current counter state.
			TMP_PREFIX="$(echo -n "${line}" | cut -d "=" -f 1,2)"
			TMP_DIB_COUNTER="$(echo -n "${line}" | cut -d "=" -f 3)"
			TMP_LAST_DIB_COUNTER="${TMP_DIB_COUNTER}"
			# 
			# Bump the disconnect counter.
			if [ ${TMP_DIB_COUNTER} -lt ${DEVICE_DISCONNECTED_IDX} ]; then
				TMP_DIB_COUNTER="$((TMP_DIB_COUNTER+1))"
				sed -i "s/${TMP_PREFIX}\=.*$/${TMP_PREFIX}\=${TMP_DIB_COUNTER}/g" "${ASSOCIATIONS_DTO}"
			fi
			# 
			# If a counter is at max, the disconnected device is considered away from all APs.
			if [ ${TMP_DIB_COUNTER} -ne ${TMP_LAST_DIB_COUNTER} ]; then
				if [ ${TMP_DIB_COUNTER} -eq ${DEVICE_DISCONNECTED_IDX} ]; then
					plCheckDevicesByCounters
				fi
			fi
			#
		done
		#
		# TASK 2
		# Detect "dead" access points.
		# We will look up the station that reported a connected STA MAC.
		# Each station is expected to send us "wrtwifistareport" events every 5 minutes.
		# If the "last_wrtwifistareport" unix timestamp recorded for the access point is too old,
		# we will assume it "dead" and remove STA MAC addresses from ASSOCIATIONS_DTO it has reported before.
		# 
		# Get a all access points that have reported a connected STA MAC.
		cat "${ASSOCIATIONS_DTO}" 2>/dev/null | grep "=0$" | cut -d "_" -f 1 | uniq | while read line; do
			# Example: line="WifiAP-04"
			#
			# Did the station already submit a "wrtwifistareport"?
			if [ -f "/tmp/${line}.last_wrtwifistareport" ]; then
				LAST_REPORT_UNIX_TIME="$(cat "/tmp/${line}.last_wrtwifistareport" 2>/dev/null | head -n 1)"
				CURRENT_UNIX_TIME="$(date +%s)"
				MINUTES_SINCE_LAST_REPORT="$(((CURRENT_UNIX_TIME-LAST_REPORT_UNIX_TIME)/60))"
				if [ ${MINUTES_SINCE_LAST_REPORT} -ge 20 ]; then
					# Dead access point detected.
					logAdd -q "disconnectIdxBumper: AP [${line}] did not submit the wrtwifistareport since more than 20 minutes. Check hardware and power supply. Will remove its associations from DTO ..."
					# 
					# Remove all STA that were reported by this AP from ASSOCIATIONS_DTO.
					sed -i "/^${line}_.*/d" "${ASSOCIATIONS_DTO}"
					# 
					# Update PRESENT_DEVICES_DTO
					plCheckDevicesByCounters
				fi
			fi
		done
		#
		sleep ${IDXBUMP_SLEEP_SECONDS}
	done
}
# ---------------------------------------------------
# -------------- END OF FUNCTION BLOCK --------------
# ---------------------------------------------------





















































#
# Check prerequisites.
if [ -f "/usr/sbin/syslog-ng" ]; then
	# syslog-ng is installed.
	# Check if 'external log server ip' is set correctly to forward the local logread to syslog-ng.
	if ( ! grep -q "option log_ip '127\.0\.0\.1'$" "/etc/config/system" ); then
		logAdd "[ERROR] You are using syslog-ng without forwarding the local syslog output to it. Set \"option log_ip '127.0.0.1'\". Stop."
		exit 99
	fi
	#
else
	logAdd "[WARN] syslog-ng is not installed. Only this AP will be monitored. Run \"opkg install syslog-ng\" if you need to monitor multiple APs."
fi
# 
if ( ! grep -q "network(ip(\"0\.0\.0\.0\") port(514)" "/etc/syslog-ng.conf" ); then
	logAdd "[WARN] syslog-ng is NOT configured to listen for incoming syslog messages from slave access points. Trying to fix ..."
	sed -i -e "s/network(ip(\".*[\"]/network(ip(\"0.0.0.0\"/g" "/etc/syslog-ng.conf"
	sed -i -e "s/network_localhost(/network(ip(\"0.0.0.0\") port(514) transport(udp) ip-protocol(6)/g" "/etc/syslog-ng.conf"
	#
	# Recheck.
	if ( ! grep -q "network(ip(\"0\.0\.0\.0\") port(514)" "/etc/syslog-ng.conf" ); then
		logAdd "[ERROR] syslog-ng is NOT configured to listen for incoming syslog messages from slave access points. Stop."
		exit 99
	fi
	/etc/init.d/syslog-ng restart
	logAdd "[INFO] Successfully reconfigured syslog-ng."
fi
# 
if ( ! grep -q "option cronloglevel '9'$" "/etc/config/system" ); then
	logAdd "[WARN] Cron log level is not reduced to \"warning\" in \"/etc/config/system\". Set \"option cronloglevel '9'\"."
fi
#
if [ "${CONFIG_WIFI_STA_REPORTS_ENABLED}" = "1" ]; then
	if [ ! -f "/root/wrtwifistareport.sh" ]; then
		logAdd "[ERROR] File missing: \"/root/wrtwifistareport.sh\". Stop."
		exit 99
	fi
	# 
	if ( ! grep -Fq "/root/wrtwifistareport.sh" "/etc/crontabs/root" ); then
		logAdd "[ERROR] Missing cron job for \"wrtwifistareport\". Stop."
		exit 99
	fi
fi
# 
if [ "${CONFIG_BLUETOOTH_REPORTS_ENABLED}" = "1" ]; then
	if [ ! -f "/root/wrtbtdevreport.sh" ]; then
		logAdd "[ERROR] File missing: \"/root/wrtbtdevreport.sh\". Stop."
		exit 99
	fi
	# 
	if ( ! grep -Fq "/root/wrtbtdevreport.sh" "/etc/crontabs/root" ); then
		logAdd "[ERROR] Missing cron job for \"wrtbtdevreport\". Stop."
		exit 99
	fi
fi
#
# Check commmand line parameters.
case "$1" in 
'debug')
	# Turn DEBUG_MODE on.
	DEBUG_MODE="1"
	# Continue script execution.
	;;
esac
#
# Service Startup.
#
if [ "${DEBUG_MODE}" = "0" ]; then
	logAdd "[INFO] Service was restarted."
	sleep 10
else
	# Log message.
	logAdd "*************"
	logAdd "[INFO] Service was restarted in DEBUG_MODE."
	# 
	# Adjust variables.
	IDXBUMP_SLEEP_SECONDS="3"
	DEVICE_DISCONNECTED_IDX="5"
	if [ ! -e "${GASERVICE_FIFO}" ]; then
		logAdd "[DEBUG] Creating file instead of FIFO [${GASERVICE_FIFO}]"
		touch "${GASERVICE_FIFO}"
	fi
fi
#
# Service Main.
# 
# Create FIFO.
rm "${EVENT_FIFO}" 2> /dev/null
mkfifo "${EVENT_FIFO}"
#
# Store script PID.
echo "$$" > "${PID_FILE}"
#
# Fork two permanently running background processes.
logreader &
disconnectIdxBumper &
#
# Wait for kill -INT from service stub.
wait
#
# We should never reach here.
#
logAdd "[INFO] End of script reached."
exit 0

