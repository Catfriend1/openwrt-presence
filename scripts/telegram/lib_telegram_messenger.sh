#!/bin/bash
#
# Version 1
#
#########################
# LIBRARY FUNCTIONS		#
#########################
libTMlogAdd ()
{
	TMP_SCRIPT_FULLFN="$(basename -- "${0}")"
	TMP_LOGFILE="/tmp/lib_telegram_messenger.log"
	TMP_LOG_MAX_LINES="10000"
	TMP_LOGSTREAM="$(tail -n ${TMP_LOG_MAX_LINES} ${TMP_LOGFILE} 2>/dev/null)"
	echo "${TMP_LOGSTREAM}" > "$TMP_LOGFILE"
	echo "$(date '+%Y-%m-%d [%H-%M-%S]') ${TMP_SCRIPT_FULLFN%.*} $*" | tee -a "${TMP_LOGFILE}"
	return 0
}


editTelegramNotification ()
{
	#
	# Usage:			editTelegramNotification "[SEARCH_TEXT_PATTERN]" "[TEXT]"
	# Example:			editTelegramNotification "test message" "Edited push message"
	# Purpose:			Edit previously sent message.
	#
	# Global variables:
	# 	[IN] LIB_TELEGRAM_BOT_APIKEY
	# 	[IN] LIB_TELEGRAM_BOT_ID
	# 	[IN] LIB_TELEGRAM_CHAT_ID
	#
	# Returns:
	# 	"0" on SUCCESS
	# 	"1" on FAILURE
	#
	# Consts.
	TMP_STN_CURL_TIMEOUT="10"
	TMP_STN_ID_CACHE="/tmp/telegram_sent_messages.txt"
	#
	# Variables.
	STN_SEARCH="${1}"
	STN_SEARCH="$(echo "${STN_SEARCH}" | sed -e 's~\\\([^\\n]\)~#§#§\1~g')"
	STN_SEARCH="$(echo -e "${STN_SEARCH//\"/\\\"}")"
	STN_SEARCH="$(echo "${STN_SEARCH}" | sed -e 's/#§#§/\\\\/g')"
	#
	STN_TEXT="${2}"
	STN_TEXT="$(echo "${STN_TEXT}" | sed -e 's~\\\([^\\n]\)~#§#§\1~g')"
	STN_TEXT="$(echo -e "${STN_TEXT//\"/\\\"}")"
	STN_TEXT="$(echo "${STN_TEXT}" | sed -e 's/#§#§/\\\\/g')"
	#
	if [ -z "${LIB_TELEGRAM_BOT_APIKEY}" ] || [ -z "${LIB_TELEGRAM_BOT_ID}" ] || [ -z "${LIB_TELEGRAM_CHAT_ID}" ]; then
		libTMlogAdd "[ERROR] editTelegramNotification FAILED. Global vars not set."
		return 1
	fi
	#
	if ( ! curl --version >/dev/null 2>&1); then
		libTMlogAdd "[ERROR] editTelegramNotification FAILED. curl is missing."
		return 1
	fi
	#
	if [ -z "${STN_SEARCH}" ] || [ -z "${STN_TEXT}" ]; then
		return 1
	fi
	#
	STN_MESSAGE_ID="$(cat "${TMP_STN_ID_CACHE}" 2>/dev/null | grep "^${LIB_TELEGRAM_CHAT_ID}-" | grep -F "$(echo "${STN_SEARCH}" | tr -d '\n')" | tail -1 | cut -d "|" -f 1 | cut -d "-" -f 2)"
	if [ -z "${STN_MESSAGE_ID}" ]; then
		libTMlogAdd "[WARN] editTelegramNotification: Failed to find previous message, fallback to new message."
		sendTelegramNotification "${2}"
		return $?
	fi
	#
	STN_CURL_RESULT="$(eval curl -s \
			--insecure \
			--max-time \""${TMP_STN_CURL_TIMEOUT}\"" \
			 "\"https://api.telegram.org/bot${LIB_TELEGRAM_BOT_ID}:${LIB_TELEGRAM_BOT_APIKEY}/editMessageText?chat_id=${LIB_TELEGRAM_CHAT_ID}&message_id=${STN_MESSAGE_ID}\"" \
			 --data-urlencode "\"text=${STN_TEXT}\"" \
			 2> /dev/null)"
	if ( ! echo "${STN_CURL_RESULT}" | grep -Fiq "\"ok\":true" ); then
		libTMlogAdd "[ERROR] editTelegramNotification: API_RESULT=${STN_CURL_RESULT},MESSAGE_ID=${STN_MESSAGE_ID}"
		return 1
	fi
	#
	# Return SUCCESS.
	return 0
}


sendTelegramNotification ()
{
	#
	# Usage:			sendTelegramNotification "[TEXT]" "[ATTACHMENT_FULLFN]"
	# Example:			sendTelegramNotification "Test push message" "/tmp/test.txt"
	# Purpose:
	# 	Send push message to Telegram Bot Chat
	#
	# Global variables:
	# 	[IN] SKIP_SENDING_PUSH_MESSAGES
	# 	[IN] STN_DISABLE_NOTIFICATION
	# 	[IN] LIB_TELEGRAM_BOT_APIKEY
	# 	[IN] LIB_TELEGRAM_BOT_ID
	# 	[IN] LIB_TELEGRAM_CHAT_ID
	#
	# Returns:
	# 	"0" on SUCCESS
	# 	"1" on FAILURE
	#
	# Consts.
	TMP_STN_CURL_TIMEOUT="60"
	TMP_STN_ID_CACHE="/tmp/telegram_sent_messages.txt"
	#
	# Variables.
	STN_TEXT="${1}"
	STN_TEXT="$(echo "${STN_TEXT}" | sed -e 's~\\\([^\\n]\)~#§#§\1~g')"
	STN_TEXT="$(echo -e "${STN_TEXT//\"/\\\"}")"
	STN_TEXT="$(echo "${STN_TEXT}" | sed -e 's/#§#§/\\\\/g')"
	STN_ATT_FULLFN="${2}"
	#
	if [ -z "${LIB_TELEGRAM_BOT_APIKEY}" ] || [ -z "${LIB_TELEGRAM_BOT_ID}" ] || [ -z "${LIB_TELEGRAM_CHAT_ID}" ]; then
		libTMlogAdd "[ERROR] sendTelegramNotification FAILED. Global vars not set."
		return 1
	fi
	#
	if ( ! curl --version >/dev/null 2>&1); then
		libTMlogAdd "[ERROR] sendTelegramNotification FAILED. curl is missing."
		return 1
	fi
	#
	if [ "${STN_TEXT}" = "--" ]; then
		STN_TEXT=""
	fi
	if [ -z "${STN_TEXT}" ] && [ -z "${STN_ATT_FULLFN}" ]; then
		return 1
	fi
	#
	if [ -z "${STN_DISABLE_NOTIFICATION}" ]; then
		STN_DISABLE_NOTIFICATION="0"
	fi
	#
	if [ "${SKIP_SENDING_PUSH_MESSAGES}" = "1" ]; then
		libTMlogAdd "[INFO] sendTelegramNotification skipped due to SKIP_SENDING_PUSH_MESSAGES == 1."
		return 1
	fi
	#
	if [ ! -z "${STN_TEXT}" ]; then
		STN_CURL_RESULT="$(eval curl -s \
				--insecure \
				--max-time \""${TMP_STN_CURL_TIMEOUT}\"" \
				 "\"https://api.telegram.org/bot${LIB_TELEGRAM_BOT_ID}:${LIB_TELEGRAM_BOT_APIKEY}/sendMessage?chat_id=${LIB_TELEGRAM_CHAT_ID}&disable_notification=${STN_DISABLE_NOTIFICATION}\"" \
				 --data-urlencode "\"text=${STN_TEXT}\"" \
				 2> /dev/null)"
		#
		# For testing purposes only.
		## STN_CURL_RESULT='{"ok":false,"result":{"message_id":0,"from":{"id":0,"is_bot":true,"first_name":"Bot","username":"Bot"},"chat":{"id":0,"first_name":"FN","last_name":"LN","username":"FNLN","type":"private"},"date":0000000000,"text":"Message first line\nMessage second line"}}'
		#
		if ( ! echo "${STN_CURL_RESULT}" | grep -Fiq "\"ok\":true" ); then
			libTMlogAdd "[ERROR] sendTelegramNotification: API_RESULT=${STN_CURL_RESULT}"
			return 1
		fi
		#
		STN_MESSAGE_ID="$(echo "${STN_CURL_RESULT}" | grep -o -E "\"message_id\":[0-9]+" | cut -d ':' -f 2)"
		echo "${LIB_TELEGRAM_CHAT_ID}-${STN_MESSAGE_ID}|${STN_TEXT}" | tr -d '\n' >> "${TMP_STN_ID_CACHE}"
		echo "" >> "${TMP_STN_ID_CACHE}"
	fi
	#
	if [ ! -z "${STN_ATT_FULLFN}" ]; then
		if [ "${STN_ATT_FULLFN##*.}" = "jpg" ]; then
			STN_CURL_RESULT="$(eval curl -q \
					--insecure \
					--max-time \""${TMP_STN_CURL_TIMEOUT}\"" \
					-F "\"photo=@${STN_ATT_FULLFN}\"" \
					 "\"https://api.telegram.org/bot${LIB_TELEGRAM_BOT_ID}:${LIB_TELEGRAM_BOT_APIKEY}/sendPhoto?chat_id=${LIB_TELEGRAM_CHAT_ID}&disable_notification=${STN_DISABLE_NOTIFICATION}\"" \
					 2> /dev/null)"
			if ( ! echo "${STN_CURL_RESULT}" | grep -Fiq "\"ok\":true" ); then
				if ( echo "${STN_CURL_RESULT}" | grep -Fiq "\"error_code\":413," ); then
					libTMlogAdd "[ERROR] sendTelegramNotification: Attachment too large. Skipping."
				else
					libTMlogAdd "[ERROR] sendTelegramNotification: API_RESULT=${STN_CURL_RESULT}"
				fi
				return 1
			fi
		elif [ "${STN_ATT_FULLFN##*.}" = "mp4" ]; then
			STN_CURL_RESULT="$(eval curl -q \
					--insecure \
					--max-time \""${TMP_STN_CURL_TIMEOUT}\"" \
					-F "\"video=@${STN_ATT_FULLFN}\"" \
					 "\"https://api.telegram.org/bot${LIB_TELEGRAM_BOT_ID}:${LIB_TELEGRAM_BOT_APIKEY}/sendVideo?chat_id=${LIB_TELEGRAM_CHAT_ID}&disable_notification=${STN_DISABLE_NOTIFICATION}\"" \
					 2> /dev/null)"
			if ( ! echo "${STN_CURL_RESULT}" | grep -Fiq "\"ok\":true" ); then
				if ( echo "${STN_CURL_RESULT}" | grep -Fiq "\"error_code\":413," ); then
					libTMlogAdd "[ERROR] sendTelegramNotification: Attachment too large. Skipping."
				else
					libTMlogAdd "[ERROR] sendTelegramNotification: API_RESULT=${STN_CURL_RESULT}"
				fi
				return 1
			fi
		else
			# Wrong file extension.
			return 1
		fi
		#
	fi
	#
	# Return SUCCESS.
	return 0
}
