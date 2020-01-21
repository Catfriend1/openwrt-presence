# openwrt-presence
OpenWrt device presence detection bash script. Works accross multiple APs. Listens to events from OpenWrt logread via syslog-ng on a master AP "passively". Can resync "actively" by executing "wrtwifistareport" on slave APs every 5 minutes in case of missed events. Outputs "device A=[present/away]" events to a /tmp/ file and FIFOs. The information can be consumed by home automation or logger software. Presence/Away state is detected representative to the whole extent of a SSID and not limited to a single AP.

# Status
v1.0-rc.1 - Script is already used in production environment with 5 OpenWrt access points.

# Documentation, Installation
Will be copied here as soon as the script is finished. See the script for instructions on how to install and use it.

# Support
Support, ideas, feedback appreciated via issue or at: https://forum.openwrt.org/t/script-how-to-get-a-mac-address-and-device-presence-list-of-authorized-wifi-clients-across-all-aps

# Showroom
- "sh /root/wrtpresence start"
```
wrtpresence: Creating new service instance ...
```

Wait a little to let the script grab initial MAC association and presence state, then execute:

- "sh /root/wrtpresence livelog"

```
2020-01-17 [13-52-29] wrtpresence_main.sh was restarted.
2020-01-21 [03-01-26] [INFO] BEGIN logreader_loop
2020-01-21 [03-04-05] plAddClient: WifiAP-04_wlan0-3 +3c:aa:bb:cc:1f:6a reason: AP-STA-CONNECTED
...
When "Catfriend1-Mobile", MAC 3c:aa:bb:cc:1f:6a is connected to one or more APs, the PRESENT event is emitted immediately.
...
2020-01-21 [03-04-05] FIFO-OUT [DEV/Catfriend1-Mobile=present] to /tmp/wrtgaservice_main.sh.event_fifo
2020-01-21 [03-56-00] plMarkClientAsDisconnected: WifiAP-04_wlan0-3 -3c:aa:bb:cc:1f:6a reason: AP-STA-DISCONNECTED
2020-01-21 [03-56-21] plAddClient: WifiAP-04_wlan0-3 3c:aa:bb:cc:1f:6a=0 reason: AP-STA-CONNECTED
2020-01-21 [07-13-09] plAddClient: WifiAP-05_wlan1 +64:aa:bb:cc:b2:08 reason: AP-STA-CONNECTED
2020-01-21 [07-58-56] plAddClient: WifiAP-02_wlan1 +24:aa:bb:cc:d2:9c reason: AP-STA-CONNECTED
2020-01-21 [07-59-12] plMarkClientAsDisconnected: WifiAP-02_wlan1 -24:aa:bb:cc:d2:9c reason: AP-STA-DISCONNECTED
2020-01-21 [08-02-05] plAddClient: WifiAP-03_wlan1 +0c:aa:bb:cc:23:51 reason: AP-STA-CONNECTED
2020-01-21 [08-02-06] plMarkClientAsDisconnected: WifiAP-03_wlan1 -0c:aa:bb:cc:23:51 reason: AP-STA-DISCONNECTED
2020-01-21 [08-03-28] plAddClient: WifiAP-05_wlan1 +34:aa:bb:cc:11:54 reason: AP-STA-CONNECTED
2020-01-21 [08-04-28] plMarkClientAsDisconnected: WifiAP-05_wlan1 -34:aa:bb:cc:11:54 reason: AP-STA-DISCONNECTED
2020-01-21 [09-00-59] plAddClient: WifiAP-04_wlan1 +48:aa:bb:cc:49:9e reason: AP-STA-CONNECTED
2020-01-21 [09-11-27] plAddClient: WifiAP-02_wlan0 +48:aa:bb:cc:49:9e reason: AP-STA-CONNECTED
2020-01-21 [09-12-43] plAddClient: WifiAP-05_wlan1-4 +d0:aa:bb:cc:02:a7 reason: AP-STA-CONNECTED
2020-01-21 [09-13-11] plAddClient: WifiAP-04_wlan1-4 +d0:aa:bb:cc:02:a7 reason: AP-STA-CONNECTED
2020-01-21 [09-14-06] plAddClient: WifiAP-01_wlan1-4 +d0:aa:bb:cc:02:a7 reason: AP-STA-CONNECTED
2020-01-21 [09-16-39] plMarkClientAsDisconnected: WifiAP-04_wlan1 -48:aa:bb:cc:49:9e reason: AP-STA-DISCONNECTED
2020-01-21 [09-18-20] plMarkClientAsDisconnected: WifiAP-05_wlan1-4 -d0:aa:bb:cc:02:a7 reason: AP-STA-DISCONNECTED
2020-01-21 [09-19-23] plMarkClientAsDisconnected: WifiAP-04_wlan1-4 -d0:aa:bb:cc:02:a7 reason: AP-STA-DISCONNECTED
2020-01-21 [09-20-52] plAddClient: WifiAP-02_wlan1-4 +d0:aa:bb:cc:02:a7 reason: AP-STA-CONNECTED
2020-01-21 [09-21-27] plAddClient: WifiAP-05_wlan1-4 d0:aa:bb:cc:02:a7=0 reason: AP-STA-CONNECTED
2020-01-21 [09-23-06] plAddClient: WifiAP-04_wlan1-4 d0:aa:bb:cc:02:a7=0 reason: AP-STA-CONNECTED
2020-01-21 [09-24-15] plMarkClientAsDisconnected: WifiAP-01_wlan1-4 -d0:aa:bb:cc:02:a7 reason: AP-STA-DISCONNECTED
2020-01-21 [09-24-15] plAddClient: WifiAP-01_wlan1-4 d0:aa:bb:cc:02:a7=0 reason: AP-STA-CONNECTED
2020-01-21 [09-26-43] plMarkClientAsDisconnected: WifiAP-02_wlan1-4 -d0:aa:bb:cc:02:a7 reason: AP-STA-DISCONNECTED
2020-01-21 [09-28-18] plMarkClientAsDisconnected: WifiAP-05_wlan1-4 -d0:aa:bb:cc:02:a7 reason: AP-STA-DISCONNECTED
2020-01-21 [09-29-22] plMarkClientAsDisconnected: WifiAP-04_wlan1-4 -d0:aa:bb:cc:02:a7 reason: AP-STA-DISCONNECTED
2020-01-21 [09-39-07] plAddClient: WifiAP-04_wlan0 +48:aa:bb:cc:49:9e reason: AP-STA-CONNECTED
2020-01-21 [09-44-28] plMarkClientAsDisconnected: WifiAP-02_wlan0 -48:aa:bb:cc:49:9e reason: AP-STA-DISCONNECTED
...
After "Catfriend1-Mobile", MAC 3c:aa:bb:cc:1f:6a disconnected from all APs, the AWAY event is emitted when it did not reconnect within 5 minutes.
...
2020-01-21 [10-56-21] plMarkClientAsDisconnected: WifiAP-04_wlan0-3 3c:aa:bb:cc:1f:6a=0 reason: AP-STA-DISCONNECTED 
2020-01-21 [11-01-20] FIFO-OUT [DEV/Catfriend1-Mobile=away] to /tmp/wrtgaservice_main.sh.event_fifo
```

- Presence state can be retrieved from flat files by other scripts in REAL time. The stats are updated immediately when a device joins the SSID.

-- Retrieve from file by MAC
```
root@WifiAP-01:~# cat "/tmp/associations.dto"
WifiAP-01_wlan1-4=d0:aa:bb:cc:02:a7=0
WifiAP-02_wlan0=48:aa:bb:cc:49:9e=5
WifiAP-02_wlan1-4=d0:aa:bb:cc:02:a7=5
WifiAP-02_wlan1=24:aa:bb:cc:d2:9c=5
WifiAP-03_wlan1=0c:aa:bb:cc:23:51=5
WifiAP-04_wlan0-3=3c:aa:bb:cc:1f:6a=0
WifiAP-04_wlan0=48:aa:bb:cc:49:9e=0
WifiAP-04_wlan1-4=d0:aa:bb:cc:02:a7=5
WifiAP-04_wlan1=48:aa:bb:cc:49:9e=5
WifiAP-05_wlan1-4=d0:aa:bb:cc:02:a7=5
WifiAP-05_wlan1=34:aa:bb:cc:11:54=5
WifiAP-05_wlan1=64:aa:bb:cc:b2:08=0
```
=0 means CONSIDERED PRESENT
>1 and <5 means CONSIDERED PRESENT BUT DISCONNECTED FOR SHORT TIME
=5 means CONSIDERED AWAY, because device did not reconnect within 5 minutes to any access point.

-- Retrieve from file by Device Name
```
# The device name is put here, if the corresponding MAC address has the counter "<5" in "/tmp/associations.dto".
root@WifiAP-01:~# cat "/tmp/present_devices.dto"
Catfriend1-Mobile
```

