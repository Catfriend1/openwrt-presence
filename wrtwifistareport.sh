#/bin/sh
#
# Info:			OpenWRT Wifi STA Syslog Reporter
# Filename:		wrtwifistareport.sh
# Usage:		This script gets called by cron every X minutes.
# 				#
#				# Force an immediate report via syslog to the collector server.
#				sh "/root/wrtwifistareport.sh"
#
# Installation:	
# 
# chmod +x "/root/wrtwifistareport.sh"
# LUCI: System / Scheduled Tasks / Add new row
# 	*/5 * * * * /bin/sh "/root/wrtwifistareport.sh" >/dev/null 2>&1
# Restart Cron:
# 	/etc/init.d/cron restart
#
# -----------------------------------------------------
# -------------- START OF FUNCTION BLOCK --------------
# -----------------------------------------------------
dumpLocalAssociatedStations ()
{
	#
	# Usage:				dumpLocalAssociatedStations
	# Returns:				iw dev <all wlan devices> station dump
	#						cumulated result.
	# Example Result:		"aa:bb:cc:dd:ee:ff|" (without newline at the end)
	#
	# Called By:			MAIN
	#
	# 
	# Get all wlan interfaces with sub-SSIDs:
	# e.g. wlan0, wlan0-1, wlan0-2, wlan1, wlan1-1, wlan1-2, ...
	iw dev | grep "wlan\|phy" | grep -v "phy#" | cut -d " " -f 2 | while read file;
	do
		#
		# "file" contains one SSID Wifi Interface, e.g. "wlan0-1"
		#
		# Get associated stations of current wlanX interface.
		# 	echo -n "$(iw dev "${file}" station dump 2> /dev/null | grep -Fi "on wlan" | cut -d " " -f 2 | sed "s/^/${file},/" | tr '\n' '|')"
		# 
		# Get authorized stations of current wlanX interface.
		echo -n "$(iw dev "${file}" station dump 2> /dev/null | grep "\(on ${file}\|authorized:*.\)" | grep -B 1 "^.*authorized:.*yes$" | grep -v "^.*authorized:.*$" | cut -d " " -f 2 | sed "s/^/${file},/" | tr '\n' '|')"
		# 
	done
	#
	# Content already returned because iw dev was called loudly.
	return
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
# Write associated STA client MAC addresses to local syslog.
# If a syslog-ng server is configured in LUCI, the log will be forwarded to it.
logger -t "wrtwifistareport" "$(echo ";$(dumpLocalAssociatedStations)")"
#
# For testing purposes only.
# echo ";$(dumpLocalAssociatedStations)"
#
exit 0
