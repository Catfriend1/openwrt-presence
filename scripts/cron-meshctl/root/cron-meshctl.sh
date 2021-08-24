#!/bin/bash
#
# Purpose:
## You have two access points, interconnected via 802.11s mesh. The mesh is the transport for multiple VLAN networks which are the underlying transport for multiple WiFi SSIDs.
## Wired uplink for VLAN 10, 20 === WifiAP-01 === 802.11s mesh SSID === WifiAP-02 === SSID "10-Intranet", SSID "20-Guest"
## If your mesh becomes disconnected, WifiAP-02 will still allow clients to log on to its "dead" SSID and the devices will complain "connected to WiFi, no local/wan connectivity".
## This script improves the situation by automatically detecting the mesh outage and disabling the SSID "10-Intranet" and "20-Guest". When the mesh comes up again, the SSID will be re-enabled.
#
# Installation:
## opkg update; opkg install bash
## chmod +x "/root/cron-meshctl.sh"
## /etc/crontabs/root
### [ADD LINE]
#### */1 * * * * /bin/bash "/root/cron-meshctl.sh" >/dev/null 2>&1
#
# Consts.
MESH_PARTNER_TIMEOUT_SECONDS="30"
# Check shell
if [ ! -n "$BASH_VERSION" ]; then
	echo "[ERROR] Wrong shell environment, please run with bash."
	exit 99
fi
#
if ( ! which batctl >/dev/null ); then
	echo "[ERROR] batctl missing. Stop."
	exit 99
fi
#
MESH_PARTNERS_CONNECTED_COUNT=0
while read lastSeenS; do
	if [ "${lastSeenS}" = "" ]; then
		continue
	fi
	if [ "${lastSeenS}" -le "${MESH_PARTNER_TIMEOUT_SECONDS}" ]; then
		MESH_PARTNERS_CONNECTED_COUNT="$((MESH_PARTNERS_CONNECTED_COUNT+1))"
	fi
done < <(batctl neighbors | tail -n +3 | awk '{print $3}' | sed 's/\..*//')
echo MESH_PARTNERS_CONNECTED_COUNT=[$MESH_PARTNERS_CONNECTED_COUNT]
#
# For testing purposes only.
## MESH_PARTNERS_CONNECTED_COUNT="0"
#
if [ "${MESH_PARTNERS_CONNECTED_COUNT}" -eq 0 ]; then
	NEW_AP_STATE="down"
else
	NEW_AP_STATE="up"
fi
#
while read bridgeIfName; do
	if [ "${bridgeIfName}" = "" ]; then
		continue
	fi
	if ( ! brctl show "${bridgeIfName}" | grep -q -E '\sbat0\..*' ); then
		# bat0.X is not a member of this bridge.
		continue
	fi
	while read wifiIfName; do
		if [ "${wifiIfName}" = "" ]; then
			continue
		fi
		echo "[INFO] Setting WiFi IF [${wifiIfName}] to [${NEW_AP_STATE}]"
		ifconfig ${wifiIfName} ${NEW_AP_STATE}
	done < <(brctl show "${bridgeIfName}" | grep -o -E "wlan[[:xdigit:]]{1}(-[[:xdigit:]]{1,})?")
done < <(brctl show | awk 'NF>1 && NR>1 {print $1}')
#
exit 0
