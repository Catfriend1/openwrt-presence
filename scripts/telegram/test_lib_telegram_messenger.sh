#!/bin/bash
#
# Command line
## bash "/root/telegram/test_lib_telegram_messenger.sh"
#
# Includes
. /root/telegram/lib_telegram_cfg_bot.sh
. /root/telegram/lib_telegram_messenger.sh
#
# Consts.
STN_DISABLE_NOTIFICATION="1"
#
# For testing purposes only.
#
sendTelegramNotification "This is a test message. DOMAIN\\test.user\nNeue\nZeile: Username=\"USER\\test.user\" high tick^ end of text QUOTE \". German Äther Ügur Öulum PUNKT" ""
echo "[DEBUG] sendTelegramNotification exited with code [$?]"
#
editTelegramNotification "test message. DOMAIN\\test.user\nNeue" "Edit^ed push message with german ÄÖU umlaut and line\nbreak."
echo "[DEBUG] editTelegramNotification exited with code [$?]"
#
sendTelegramNotification "$(date)" "/root/telegram/test_lib_telegram_messenger_1.jpg /root/telegram/test_lib_telegram_messenger_2.jpg"
echo "[DEBUG] editTelegramNotification exited with code [$?]"
#
exit 0
