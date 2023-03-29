#!/bin/sh
#
# Command line.
## sh /root/watchcat.user.sh
#
logread | grep "DFS-RADAR-DETECTED" && reboot
#
exit 0
