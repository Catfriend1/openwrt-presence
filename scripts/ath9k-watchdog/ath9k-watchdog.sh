#/bin/bash
#
# Purpose:
# 	Watch ath9k 2.4 GHz wadio event 60 and if the event occurs, trigger a WiFi scan as a workaround to avoid issues
# 	slowly creeping up like higher WiFi latency or unexpected WiFi client disconnects.
#
# Installation:
#	bash "/root/ath9k-watchdog.sh" install
#
# Command line:
# 	bash "/root/ath9k-watchdog.sh" livelog
# 	bash "/root/ath9k-watchdog.sh" start &
# 	bash "/root/ath9k-watchdog.sh" stop
#
# For testing purposes only:
# 	bash "/root/ath9k-watchdog.sh" start
#
# Prerequisites:
#	BASH
#
# Script Configuration.
PATH=/usr/bin:/usr/sbin:/sbin:/bin
SCRIPT_FULLFN="$(basename -- "${0}")"
SCRIPT_NAME="${SCRIPT_FULLFN%.*}"
LOGFILE="/tmp/${SCRIPT_NAME}.log"
LOG_MAX_LINES="1000"
#
#
# -----------------------------------------------------
# -------------- START OF FUNCTION BLOCK --------------
# -----------------------------------------------------
logAdd ()
{
	TMP_DATETIME="$(date '+%Y-%m-%d [%H-%M-%S]')"
	TMP_LOGSTREAM="$(tail -n ${LOG_MAX_LINES} ${LOGFILE} 2>/dev/null)"
	echo "${TMP_LOGSTREAM}" > "$LOGFILE"
	echo "${TMP_DATETIME} $*" | tee -a "${LOGFILE}"
	return
}


serviceMain ()
{
	#
	# Usage:		serviceMain
	# Called By:	MAIN
	#
	logAdd "[INFO] === SERVICE START ==="
	#
	logAdd "[INFO] Waiting to discover 2.4 GHz radio interface ..."
	while (true); do
		RADIO_ATH9K="$(iw dev|grep "Interface\|channel\|type"|grep -B 2 'channel.*24..'|grep -B 1 'AP'|tail -n 2|grep Interface|awk '{print $2}')"
		if [ ! -z "${RADIO_ATH9K}" ]; then
			break
		fi
		sleep 10
	done
	#
	logAdd "[INFO] Setup iw_event_scan_trigger on interface [${RADIO_ATH9K}]"
	#
	dt=0
	iw event -t -f | while read line; do
		if $(echo -n "${line}" | grep -q "${RADIO_ATH9K}.*: unknown event 60"); then
			#
			# Check if the last scan was more than 10 seconds ago.
			if [ ${line%%.*} -gt ${dt} ] ; then
				echo "$(date +%Y-%m-%d_%H-%M-%S): ${dt} ${RADIO_ATH9K} scan ..."
				iw dev ${RADIO_ATH9K} scan trigger freq 2447 flush >/dev/null 2>&1
				dt=$(($(date +%s)+10))
			fi
		fi
	done
	#
	return 0
}
# ---------------------------------------------------
# -------------- END OF FUNCTION BLOCK --------------
# ---------------------------------------------------
#
# Check shell
if [ ! -n "${BASH_VERSION}" ]; then
	logAdd "[ERROR] Wrong shell environment, please run with bash."
	exit 99
fi
#
trap "" SIGHUP
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT
#
if [ "${1}" = "install" ]; then
	if ( grep -q "$(which bash) $(readlink -f "${0}") start &" "/etc/rc.local"); then
		echo "[INFO] Script already present in startup."
		exit 0
	fi
	sed -i "\~^exit 0~i $(which bash) $(readlink -f "${0}") start &\n" "/etc/rc.local"
	echo "[INFO] Script successfully added to startup."
	exit 0
elif [ "${1}" = "livelog" ]; then
	tail -f "${LOGFILE}"
	exit 0
elif [ "${1}" = "start" ]; then
	serviceMain &
	#
	# Wait for kill -INT.
	wait
	exit 0
elif [ "${1}" = "stop" ]; then
	ps w | grep -v grep | grep "$(basename -- $(which bash)) .*$(basename -- ${0}) start" | sed 's/ \+/|/g' | sed 's/^|//' | cut -d '|' -f 1 | grep -v "^$$" | while read pidhandle; do
		echo "[INFO] Terminating old service instance [${pidhandle}] ..."
		kill -INT "${pidhandle}" 2>/dev/null
		kill "${pidhandle}" 2>/dev/null
	done
	#
	# Check if parts of the service are still running.
	if [ "$(ps w | grep -v grep | grep "$(basename -- $(which bash)) .*$(basename -- ${0}) start" | sed 's/ \+/|/g' | sed 's/^|//' | cut -d '|' -f 1 | grep -v "^$$" | wc -l)" -gt 0 ]; then
		logAdd "[ERROR] === SERVICE FAILED TO STOP ==="
		ps w | grep "iw event\|${SCRIPT_NAME}" | grep -v grep
		exit 99
	fi
	#
	killall iw 2>/dev/null
	#
	logAdd "[INFO] === SERVICE STOPPED ==="
	exit 0
fi
#
logAdd "[ERROR] Parameter #1 missing."
logAdd "[INFO] Usage: bash ${SCRIPT_FULLFN} {install|livelog|start|stop}"
exit 99
