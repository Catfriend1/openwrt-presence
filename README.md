# openwrt-presence
OpenWrt device presence detection bash script. Works accross multiple APs. Listens to events from OpenWrt logread via syslog-ng on a master AP "passively". Can resync "actively" by executing "wrtwifistareport" on slave APs every 5 minutes in case of missed events. Outputs "device A=[present/away]" events to a /tmp/ file and FIFOs. The information can be consumed by home automation or logger software. Presence/Away state is detected representative to the whole extent of a SSID and not limited to a single AP.

# Documentation
Will be copied here as soon as the script is finished. See the script for instructions on how to install and use it.

# Support
Support, ideas, feedback appreciated via issue or at: https://forum.openwrt.org/t/script-how-to-get-a-mac-address-and-device-presence-list-of-authorized-wifi-clients-across-all-aps

# Showroom
- "sh /root/wrtpresence livelog"


```
a
```
