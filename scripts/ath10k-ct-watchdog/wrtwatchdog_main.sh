#/bin/bash
trap "" SIGHUP
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT
#
# Info:				OpenWRT Watchdog Service Main Loop
# Usage:			This script gets instanced by "wrtwatchdog".
# Prerequisites:
#	BASH
# 	wrtwatchdog								main service wrapper
# 	wrtwatchdog_main.sh						main service program
# 
# For testing purposes only:
# 	killall logread; killall tail; sh wrtwatchdog stop; bash wrtwatchdog_main.sh debug
# 	kill -INT "$(cat "/tmp/wrtwatchdog_main.sh.pid")"
#
# Script Configuration.
PATH=/usr/bin:/usr/sbin:/sbin:/bin
CURRENT_SCRIPT_PATH="$(cd "$(dirname "$0")"; pwd)"
PID_FILE=/tmp/"$(basename "$0")".pid
LOGFILE="/tmp/wrtwatchdog.log"
LOG_MAX_LINES="1000"
DEBUG_MODE="0"
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
	# Quiet mode.
	echo "${TMP_DATETIME} $*" >> "${LOGFILE}"
	return
}


logreader() {
	#
	# Called by:	MAIN
	#
	logAdd "[INFO] BEGIN logreader_loop"
	/sbin/logread -f | while read line; do
		# The filter is compatible with both syslog-ng and logd output.
		if $(echo -n "${line}" | grep -q "kernel.*ath10k_pci.*failed to send pdev bss chan info request"); then
			logAdd "[ERROR] ath10k_pci 5G WiFi card failed. Restarting driver ..."
			cp -f "${LOGFILE}" "/root/"
			rmmod ath10k_pci
			sleep 5
			modprobe ath10k_pci
			sleep 5
			logAdd "[INFO] Restarting wifi after driver restart ..."
			wifi up
		fi
	done
}
# ---------------------------------------------------
# -------------- END OF FUNCTION BLOCK --------------
# ---------------------------------------------------
#
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
if [ "${DEBUG_MODE}" = "0" ]; then
	logAdd "[INFO] Script has been restarted."
	sleep 10
else
	# Log message.
	logAdd "[INFO] Script was restarted in DEBUG_MODE."
fi
#
# Service Main.
#
# Store script PID.
echo "$$" > "${PID_FILE}"
#
# Fork permanently running background process.
logreader &
#
# Wait for kill -INT from service stub.
wait
#
# We should never reach here.
logAdd "[INFO] End of script reached."
exit 0
