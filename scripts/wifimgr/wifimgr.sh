#!/bin/bash
### Documentation at: https://forum.openwrt.org/t/a-kiss-wifi-manager-script-to-push-etc-config-wireless-using-a-central-mgmt-server
#
# Check shell
if [ ! -n "$BASH_VERSION" ]; then
	echo "[WARN] Wrong shell environment, trying to restart using BASH"
	/bin/bash "${0}" "$@"
	exit 0
fi
#
# Command line parameters:
# 	disable-ssid	- Disable given SSID on all access points
# 						e.g. bash /srv/wifimgr/wifimgr.sh disable-ssid Guest
# 	enable-ssid		- Enable given SSID on all access points
# 						e.g. bash /srv/wifimgr/wifimgr.sh enable-ssid Guest
# 	night			- Enable night mode, this disables most Ssid's
# 	[empty]			- Disable night mode, re-enable all Ssid's
#
# Prerequisites:
# 	bash required because of "while read x; do ... done <<<$(cmd)"
#
# Notes:
# 	ssh -o "StrictHostKeyChecking=no" -i "/etc/ssh/ssh_host_rsa_key" root@IP
#
# 	# On syslog collector
# 	logread -f | grep -v "dropbear"
# 	tail -f "/tmp/wifimgr.log"
#
# Script Configuration.
SSH_PRIVATE_KEY="/etc/ssh/ssh_host_rsa_key"
DRY_RUN="0"
#
# Runtime Variables.
SCRIPT_NAMEEXT="$(basename -- "$(realpath "${0}")")"
SCRIPT_NAME="${SCRIPT_NAMEEXT%.*}"
SCRIPT_PATH="$(dirname "$(realpath "${0}")")"
LOGFILE="/tmp/${SCRIPT_NAME}.log"
LOG_MAX_LINES="1000"
# 
#########################
# FUNCTION BLOCK START 	#
#########################
commitDeviceConfig ()
{
	#
	# Syntax:			commitDeviceConfig [device_ip] [use_case_tag] [commit_delay_secs]
	# Example:			commitDeviceConfig "192.168.1.1" "upstairs" "0"
	# Called By:		updateDeviceConfig
	# 
	# Global vars:
	# 	[IN] SSH_PRIVATE_KEY
	# 
	# Consts.
	TMP_MY_FUNC_TAG=""
	#
	# Variables.
	TMP_DEVICE_IP="${1}"
	TMP_USE_CASE_TAG="${2}"
	TMP_COMMIT_DELAY_SECS="${3}"
	#
	if [ -z "${TMP_DEVICE_IP}" ]; then
		logAdd "[ERROR] commitDeviceConfig: Param 1 device_ip missing."
		return 99
	fi
	#
	if [ -z "${TMP_USE_CASE_TAG}" ]; then
		logAdd "[ERROR] commitDeviceConfig: Param 2 use_case_tag missing."
		return 99
	fi
	#
	if [ -z "${TMP_COMMIT_DELAY_SECS}" ]; then
		logAdd "[ERROR] commitDeviceConfig: Param 3 commit_delay_secs missing."
		return 99
	fi
	#
	# Execute "wifi reload" on the device.
	logAdd "[INFO] ${TMP_MY_FUNC_TAG}[${TMP_DEVICE_IP}] '${TMP_USE_CASE_TAG}': Config commit in ${TMP_COMMIT_DELAY_SECS}s ..."
	sendSshCmdToDevice "${TMP_DEVICE_IP}" "logger -t wifimgr Committing changes in ${TMP_COMMIT_DELAY_SECS}s; sleep ${TMP_COMMIT_DELAY_SECS}; wifi reload"
	if [ $? -ne 0 ]; then
		logAdd "[ERROR] ${TMP_MY_FUNC_TAG}[${TMP_DEVICE_IP}] '${TMP_USE_CASE_TAG}': Config commit FAILED."
		return 99
	fi
	#
	logAdd "[INFO] ${TMP_MY_FUNC_TAG}[${TMP_DEVICE_IP}] '${TMP_USE_CASE_TAG}': Config commit successful."
	return 0
}


generateDeviceConfig ()
{
	#
	# Syntax:			generateDeviceConfig [output_folder] [device_ip] [use_case_tag] [device_manufacturer_model]
	# Example:			generateDeviceConfig "/root/wifimgr/generated" "192.168.1.1" "upstairs" "archer-c7-v2"
	# Called By:		updateDeviceConfig
	#
	# Global vars:
	# 	[IN] G_PARAM_DISABLE_SSID
	# 	[IN] G_PARAM_ENABLE_SSID
	# 	[IN] G_PARAM_NIGHT
	# 	[IN] G_PARAM_SSID
	# 	[IN] SCRIPT_PATH
	# 
	# Consts.
	TMP_MY_FUNC_TAG=""
	#
	# Variables.
	TMP_OUTPUT_FOLDER="${1}"
	TMP_DEVICE_IP="${2}"
	TMP_USE_CASE_TAG="${3}"
	TMP_DEVICE_MANUFACTURER_MODEL="${4}"
	#
	if [ -z "${TMP_OUTPUT_FOLDER}" ]; then
		logAdd "[ERROR] generateDeviceConfig: Param 1 output_folder missing."
		return 99
	fi
	#
	if [ -z "${TMP_DEVICE_IP}" ]; then
		logAdd "[ERROR] generateDeviceConfig: Param 2 device_ip missing."
		return 99
	fi
	#
	if [ -z "${TMP_USE_CASE_TAG}" ]; then
		logAdd "[ERROR] generateDeviceConfig: Param 3 use_case_tag missing."
		return 99
	fi
	#
	if [ -z "${TMP_DEVICE_MANUFACTURER_MODEL}" ]; then
		logAdd "[ERROR] generateDeviceConfig: Param 4 device_manufacturer_model missing."
		return 99
	fi
	#
	logAdd "[INFO] ${TMP_MY_FUNC_TAG}[${TMP_DEVICE_IP}] '${TMP_USE_CASE_TAG}': Generating config"
	#
	# Runtime variables.
	TMP_CFG_WIRELESS="${TMP_OUTPUT_FOLDER}/wireless"
	#
	if [ ! -d "${SCRIPT_PATH}/radio-iface" ]; then
		logAdd "[ERROR] generateDeviceConfig: [${SCRIPT_PATH}/radio-iface] does not exist."
		return 99
	fi
	#
	# Parse and merge radio interface definition files.
	echo "" > "${TMP_CFG_WIRELESS}"
	while read file; do
		#
		# Check if template is restricted to a set of use cases.
		if ( grep -q "^#\s*applyUseCase:" "${file}" ); then
			#
			# Check if use case applies because template contains a use case restriction.
			if ( ! grep -q "^#\s*applyUseCase:.*${TMP_USE_CASE_TAG}.*" "${file}" ); then
				logAdd "[INFO] ${TMP_MY_FUNC_TAG}[${TMP_DEVICE_IP}] '${TMP_USE_CASE_TAG}' Skipping template '${file##*/}', reason: generic use case restriction"
				continue
			fi
		fi
		# Extract "radioX" from template.
		TMP_RADIO_IF_SSID="$(cat "${file}" | sed "s/^#\s*//" | grep "^config wifi-device 'radio.*'" | cut -d "'" -f 2)"
		#
		logAdd "[INFO] ${TMP_MY_FUNC_TAG}[${TMP_DEVICE_IP}] '${TMP_USE_CASE_TAG}' Applying template '${file##*/}' (${TMP_RADIO_IF_SSID})"
		#
		cat "${file}" | sed -e "/^#.*$/d" >> "${TMP_CFG_WIRELESS}"
		echo "" >> "${TMP_CFG_WIRELESS}"
	done <<<$(find "${SCRIPT_PATH}/radio-iface/" -mindepth 1 -maxdepth 1 -type f | sort -k 1 -n)
	#
	if [ ! -d "${SCRIPT_PATH}/wifi-iface" ]; then
		logAdd "[ERROR] generateDeviceConfig: [${SCRIPT_PATH}/wifi-iface] does not exist."
		return 99
	fi
	#
	# Parse and merge wifi interface definition files.
	TMP_WIFINET_IDX=0
	while read file; do
		#
		# logAdd "[INFO] ${TMP_MY_FUNC_TAG}[${TMP_DEVICE_IP}] '${TMP_USE_CASE_TAG}' Processing template '${file##*/}'"
		#
		# Check if template is restricted to a set of use cases.
		if ( grep -q "^#\s*applyUseCase:" "${file}" ); then
			#
			# Check if use case applies because template contains a use case restriction.
			if ( ! grep -q "^#\s*applyUseCase:.*${TMP_USE_CASE_TAG}.*" "${file}" ); then
				logAdd "[INFO] ${TMP_MY_FUNC_TAG}[${TMP_DEVICE_IP}] '${TMP_USE_CASE_TAG}' Skipping template '${file##*/}', reason: generic use case restriction"
				continue
			fi
		fi
		#
		# Extract SSID from template.
		TMP_WIFI_IF_SSID="$(cat "${file}" | sed "s/^#\s*//" | egrep "^\s*option ssid|^\s*option mesh_id" | cut -d "'" -f 2)"
		#
		logAdd "[INFO] ${TMP_MY_FUNC_TAG}[${TMP_DEVICE_IP}] '${TMP_USE_CASE_TAG}' Applying template '${file##*/}' (${TMP_WIFI_IF_SSID})"
		#
		# Check if SSID should be disabled.
		TMP_WIFI_IF_DISABLED=""
		if [ "${TMP_WIFI_IF_SSID}" = "${G_PARAM_SSID}" ]; then
			if [ "${G_PARAM_DISABLE_SSID}" = "1" ]; then
				TMP_WIFI_IF_DISABLED="1"
			elif [ "${G_PARAM_ENABLE_SSID}" = "1" ]; then
				TMP_WIFI_IF_DISABLED="0"
			fi
		fi
		#
		# Get applicable radios.
		while read radio; do
			radio="$(echo "${radio}" | cut -d ":" -f 1)"
			# logAdd "[INFO] ${TMP_MY_FUNC_TAG}... ${radio}"
			#
			# Check if the radio should apply use case restricted.
			if ( grep -q "^#\s*${radio}:" "${file}" ); then
				#
				# Check if use case applies because template contains a use case restriction.
				# e.g. "radio0:use_case_tag1,use_case_tag2"
				if ( ! grep -q "^#\s*${radio}:.*${TMP_USE_CASE_TAG}.*" "${file}" ); then
					# logAdd "[INFO] ${TMP_MY_FUNC_TAG}[${TMP_DEVICE_IP}] '${TMP_USE_CASE_TAG}' Skipping template '${file##*/}', reason: ${radio} use case restriction"
					continue
				fi
			fi
			#
			TMP_FILE_BUFFER="$(cat "${file}" | sed -e "/^#.*$/d" -e "s/'radioX'/'${radio}'/" -e "s/'wifinetX'/'wifinet${TMP_WIFINET_IDX}'/")"
			#
			# Disable if requested.
			TMP_FILE_BUFFER="$(echo "${TMP_FILE_BUFFER}" | sed "s/option disabled 'X'/option disabled '${G_PARAM_NIGHT}'/")"
			if [ ! -z "${TMP_WIFI_IF_DISABLED}" ]; then
				TMP_FILE_BUFFER="$(echo "${TMP_FILE_BUFFER}" | sed "s/option disabled '.'/option disabled '${TMP_WIFI_IF_DISABLED}'/")"
			fi
			#
			# MAC filter entries can be restricted to a list of given access points.
			## Example: This MAC address is never listed on the access point "upstairs".
			### list maclist 'aa:bb:cc:dd:ee:ff'		# removeUseCase:upstairs
			TMP_FILE_BUFFER="$(echo "${TMP_FILE_BUFFER}" | sed "/[ \t]*#\s*removeUseCase:.*${TMP_USE_CASE_TAG}.*/d" | sed "s/[ \t]*#\s*removeUseCase:.*$//")"
			#
			# MAC filter entries can be restricted to a list of given radios.
			## Example: This MAC address is never listed on the radio1 - 2.4 GHz.
			### list maclist 'aa:bb:cc:dd:ee:ff'		# removeFromRadio:radio1
			TMP_FILE_BUFFER="$(echo "${TMP_FILE_BUFFER}" | sed "/[ \t]*#\s*removeFromRadio:.*${radio}.*/d" | sed "s/[ \t]*#\s*removeFromRadio:.*$//")"
			#
			echo "${TMP_FILE_BUFFER}" >> "${TMP_CFG_WIRELESS}"
			echo "" >> "${TMP_CFG_WIRELESS}"
			TMP_WIFINET_IDX="$((TMP_WIFINET_IDX+1))"
		done <<<$(cat "${file}" | grep "^#\s*radio[0-9].*$" | sed "s/^#\s*//")
	done <<<$(find "${SCRIPT_PATH}/wifi-iface/" -mindepth 1 -maxdepth 1 -type f | sort -k 1 -n)
	logAdd "[INFO] ${TMP_MY_FUNC_TAG}[${TMP_DEVICE_IP}] '${TMP_USE_CASE_TAG}' Merged ${TMP_WIFINET_IDX} WiFi interfaces"
	#
	# printWifiCfg "${TMP_CFG_WIRELESS}"
	#
	return 0
}


logAdd ()
{
	TMP_DATETIME="$(date '+%Y-%m-%d [%H-%M-%S]')"
	TMP_LOGSTREAM="$(tail -n ${LOG_MAX_LINES} ${LOGFILE} 2>/dev/null)"
	echo "${TMP_LOGSTREAM}" > "$LOGFILE"
	if [ "$1" = "-q" ]; then
		#
		# Quiet mode.
		echo "${TMP_DATETIME} ${@:2}" >> "${LOGFILE}"
	else
		#
		# Loud mode.
		echo "${TMP_DATETIME} $*" | tee -a "${LOGFILE}"
	fi
	return 0
}


printWifiCfg ()
{
	# 
	# Syntax:			printWifiCfg [CONFIG_FULLFN]
	# Called By:		generateDeviceConfig
	# 
	TMP_CFG_FILE="${1}"
	echo ""
	echo "[INFO] ===================================================="
	echo "[INFO] === Printing \"${TMP_CFG_FILE}\"	==="
	echo "[INFO] ===================================================="
	cat ${TMP_CFG_FILE}
	echo "[INFO] ==="
	# 
	return 0
}


sendSshCmdToDevice ()
{
	# 
	# Syntax:			sendSshCmdToDevice [DEVICE_IP] [SSH_COMMAND]
	# Called By:		commitDeviceConfig
	#
	# Global vars:
	# 	[IN] SSH_PRIVATE_KEY
	# 
	# Variables.
	TMP_DEVICE_IP="${1}"
	TMP_SSH_CMD="${2}"
	# 
	ssh -o "StrictHostKeyChecking=no" -i "${SSH_PRIVATE_KEY}" "root@${TMP_DEVICE_IP}" "${TMP_SSH_CMD}"
	return $?
}


updateDeviceConfig ()
{
	#
	# Syntax:			updateDeviceConfig [device_ip] [use_case_tag] [device_manufacturer_model] [commit_delay_secs]
	# Example:			updateDeviceConfig "192.168.1.1" "upstairs" "archer-c7-v2" "0"
	# Called By:		MAIN
	#
	# Global vars:
	# 	[IN] DRY_RUN
	# 	[IN] G_PARAM_DISABLE_SSID
	# 	[IN] G_PARAM_ENABLE_SSID
	# 	[IN] G_PARAM_NIGHT
	# 	[IN] G_PARAM_SSID
	# 	[IN] SCRIPT_PATH
	# 	[IN] SSH_PRIVATE_KEY
	# 
	# Consts.
	TMP_MY_FUNC_TAG=""
	#
	# Variables.
	#
	# Variables.
	TMP_DEVICE_IP="${1}"
	TMP_USE_CASE_TAG="${2}"
	TMP_DEVICE_MANUFACTURER_MODEL="${3}"
	TMP_COMMIT_DELAY_SECS="${4}"
	#
	if [ -z "${TMP_DEVICE_IP}" ]; then
		logAdd "[ERROR] updateDeviceConfig: Param 1 device_ip missing."
		return 99
	fi
	#
	if [ -z "${TMP_USE_CASE_TAG}" ]; then
		logAdd "[ERROR] updateDeviceConfig: Param 2 use_case_tag missing."
		return 99
	fi
	#
	if [ -z "${TMP_DEVICE_MANUFACTURER_MODEL}" ]; then
		logAdd "[ERROR] updateDeviceConfig: Param 3 device_manufacturer_model missing."
		return 99
	fi
	#
	if [ -z "${TMP_COMMIT_DELAY_SECS}" ]; then
		logAdd "[ERROR] updateDeviceConfig: Param 4 commit_delay_secs missing."
		return 99
	fi
	#
	TMP_UDC_OUTPUT_FOLDER="${SCRIPT_PATH}/generated/device_${TMP_DEVICE_IP}"
	mkdir -p "${TMP_UDC_OUTPUT_FOLDER}"
	generateDeviceConfig "${TMP_UDC_OUTPUT_FOLDER}" "${TMP_DEVICE_IP}" "${TMP_USE_CASE_TAG}" "${TMP_DEVICE_MANUFACTURER_MODEL}"
	if [ $? -ne 0 ]; then
		logAdd "[ERROR] generateDeviceConfig FAILED."
		return 99
	fi
	#
	if [ ! "${DRY_RUN}" = "0" ]; then
		logAdd "[INFO] ${TMP_MY_FUNC_TAG}[${TMP_DEVICE_IP}] '${TMP_USE_CASE_TAG}': Skipping upload to device due to DRY_RUN=1."
		return 99
	fi
	#
	uploadDeviceConfig "${TMP_UDC_OUTPUT_FOLDER}" "${TMP_DEVICE_IP}" "${TMP_USE_CASE_TAG}"
	if [ $? -ne 0 ]; then
		return 99
	fi
	#
	commitDeviceConfig "${TMP_DEVICE_IP}" "${TMP_USE_CASE_TAG}" "${TMP_COMMIT_DELAY_SECS}" &
	#
	return 0
}


uploadDeviceConfig ()
{
	#
	# Syntax:			uploadDeviceConfig [output_folder] [device_ip] [use_case_tag]
	# Example:			uploadDeviceConfig "/root/wifimgr/generated" "192.168.1.1" "og"
	# Called By:		updateDeviceConfig
	# Global vars:
	# 	[IN] SSH_PRIVATE_KEY
	# 
	# Consts.
	TMP_MY_FUNC_TAG=""
	#
	# Variables.
	TMP_OUTPUT_FOLDER="${1}"
	TMP_DEVICE_IP="${2}"
	TMP_USE_CASE_TAG="${3}"
	#
	if [ -z "${TMP_OUTPUT_FOLDER}" ]; then
		logAdd "[ERROR] uploadDeviceConfig: Param 1 output_folder missing."
		return 99
	fi
	#
	if [ -z "${TMP_DEVICE_IP}" ]; then
		logAdd "[ERROR] uploadDeviceConfig: Param 2 device_ip missing."
		return 99
	fi
	#
	if [ -z "${TMP_USE_CASE_TAG}" ]; then
		logAdd "[ERROR] uploadDeviceConfig: Param 3 use_case_tag missing."
		return 99
	fi
	#
	# Transfer config to device.
	TMP_CFG_WIRELESS="${TMP_OUTPUT_FOLDER}/wireless"
	logAdd "[INFO] ${TMP_MY_FUNC_TAG}[${TMP_DEVICE_IP}] '${TMP_USE_CASE_TAG}': Config upload ..."
	scp -q -o "StrictHostKeyChecking=no" -i "${SSH_PRIVATE_KEY}" "${TMP_CFG_WIRELESS}" "root@${TMP_DEVICE_IP}:/etc/config/wireless"
	if [ $? -ne 0 ]; then
		logAdd "[ERROR] ${TMP_MY_FUNC_TAG}[${TMP_DEVICE_IP}] '${TMP_USE_CASE_TAG}': Config upload FAILED."
		return 99
	fi
	#
	return 0
}
#########################
# FUNCTION BLOCK END 	#
#########################
#
# Verify SSH prerequisites.
if [ ! -f "${SSH_PRIVATE_KEY}" ]; then
	logAdd "[ERROR] SSH_PRIVATE_KEY=[${SSH_PRIVATE_KEY}] is missing."
	exit 99
fi
chmod 0600 "${SSH_PRIVATE_KEY}"
#
# Parse command-line parameters.
#
if [ "${1}" = "dry" ]; then
	logAdd "[INFO] Param 'dry' set."
	DRY_RUN="1"
fi
#
G_PARAM_NIGHT="0"
if [ "${1}" = "night" ]; then
	logAdd "[INFO] Param 'night' set"
	G_PARAM_NIGHT="1"
fi
#
if [ "${1}" = "?" ]; then
	echo "[INFO] Usage: bash ${SCRIPT_NAMEEXT} [disable-ssid|enable-ssid|dry|night|?]"
	exit 99
fi
#
G_PARAM_DISABLE_SSID="0"
G_PARAM_ENABLE_SSID="0"
G_PARAM_SSID=""
if [ "${1}" = "disable-ssid" ]; then
	if [ -z "${2}" ]; then
		logAdd "[ERROR] Paramter 2 SSID missing."
		exit 99
	fi
	G_PARAM_DISABLE_SSID="1"
	G_PARAM_SSID="${2}"
	logAdd "[INFO] Param 'disable-ssid' set, SSID '${G_PARAM_SSID}'"
elif [ "${1}" = "enable-ssid" ]; then
	if [ -z "${2}" ]; then
		logAdd "[ERROR] Paramter 2 SSID missing."
		exit 99
	fi
	G_PARAM_ENABLE_SSID="1"
	G_PARAM_SSID="${2}"
	logAdd "[INFO] Param 'enable-ssid' set, SSID '${G_PARAM_SSID}'"
fi
#
# Script Main.
updateDeviceConfig "192.168.1.201" "ap01-office" "archer-c7-v2" "5"
updateDeviceConfig "192.168.1.202" "ap02-storage" "archer-c7-v5" "10"
updateDeviceConfig "192.168.1.203" "ap03-welcomeroom" "archer-c7-v2" "15"
#
# Wait until all subshells finished.
wait
# 
# End of Script.
logAdd "[INFO] Done."
exit 0
