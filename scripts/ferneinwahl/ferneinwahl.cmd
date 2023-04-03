@echo off
setlocal enabledelayedexpansion
chcp 65001 1> NUL:
mode con lines=50 cols=120
title %~n0
color 1F
SET SCRIPT_PATH=%~dps0
cd /d "%SCRIPT_PATH%"
REM
REM Remote
REM 	vncviewer -listen 25900
REM
REM Consts.
SET CHECKSUM_ULTRAVNC_ZIP="BCFC72748479693B517A0825F174629A465832E1030C54DA9E09A6FDCB01B708"
SET URL_ULTRAVNC_ZIP="https://uvnc.com/component/jdownloads/send/0-/437-ultravnc-1-4-09-bin-zip.html?Itemid=0"
SET "TGT_IP=domain.tld"
SET TGT_PORT=25900
REM
REM Variables.
SET LOGFILE="%TEMP%\%~n0.log"
SET ULTRAVNC_INI="%TEMP%\ultravnc.ini"
SET WINVNC_EXE="%TEMP%\winvnc.exe"
REM
REM Check for elevated administrative privileges.
openfiles 1>NUL: 2>&1 || (call :missingElevation & goto :eof)
REM
IF NOT DEFINED TGT_IP call :logAdd "[ERROR] Initialisierung fehlgeschlagen. Abbruch." & pause & goto :eof
REM
IF "%1" == "/sessionWatchdog" goto :sessionWatchdogInit
REM
IF NOT DEFINED WIX call :askUserToConsent
REM
IF NOT EXIST %WINVNC_EXE% call :downloadUltraVNC
IF NOT EXIST %WINVNC_EXE% call :logAdd "[ERROR] Datei nicht gefunden: [%WINVNC_EXE%]" & pause & goto :eof
REM
call :logAdd "[INFO] Initialisiere ..."
REM
nslookup "%TGT_IP%" 2>NUL: | findstr "Name:" >NUL: || (call :logAdd "[ERROR] Die Gegenstelle wurde nicht gefunden. Abbruch." & pause & goto :eof)
REM
REM Verify download.
powershell -ExecutionPolicy "ByPass" (Get-FileHash -Path %WINVNC_EXE%).Hash | findstr %CHECKSUM_ULTRAVNC_ZIP% >NUL: 2>&1 || (call :logAdd "[ERROR] Die Checksumme stimmt nicht. Abbruch." & pause & goto :eof)
REM
call :writeConfig
REM
call :logAdd "[INFO] Die Sitzung wird verbunden ..."
REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "ConsentPromptBehaviorAdmin" /t REG_DWORD /d 0 /f 1>NUL:
REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "EnableLUA" /t REG_DWORD /d 0 /f 1>NUL:
REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "PromptOnSecureDesktop" /t REG_DWORD /d 0 /f 1>NUL:
call :connectSession
call :launchWatchdog
REM
call :logAdd "[INFO] Drücken Sie die Leertaste, um die Sitzung zu beenden."
pause
REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "ConsentPromptBehaviorAdmin" /t REG_DWORD /d 5 /f 1>NUL:
REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "EnableLUA" /t REG_DWORD /d 1 /f 1>NUL:
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "PromptOnSecureDesktop" /t REG_DWORD /d 1 /f 1>NUL:
REM
call :logAdd "[INFO] Beenden ..."
call :killService
REM
DEL /F /Q %ULTRAVNC_INI% >NUL: 2>&1
IF NOT DEFINED WIX DEL /F /Q %WINVNC_EXE% >NUL: 2>&1
REM
call :sleepSecs 3
goto :eof


:logAdd
REM Syntax:
REM		logAdd [TEXT]
SET LOG_TEXT=%1
SET LOG_TEXT=%LOG_TEXT:"=%
SET LOG_DATETIMESTAMP=%DATE:~-4%-%DATE:~-7,-5%-%DATE:~-10,-8%_%time:~-11,2%:%time:~-8,2%:%time:~-5,2%
SET LOG_DATETIMESTAMP=%LOG_DATETIMESTAMP: =0%
echo %LOG_DATETIMESTAMP%: %LOG_TEXT%
echo %LOG_DATETIMESTAMP%: %LOG_TEXT% >> "%LOGFILE%"
goto :eof


:askUserToConsent
REM
echo [INFO] Möchten Sie die Sitzung starten?
choice /C JN
SET CHOICE_RESULT=%ERRORLEVEL%
echo.
IF NOT "%CHOICE_RESULT%" == "1" goto :askUserToConsent
REM
goto :eof


:connectSession
REM
call :killService
copy /y "winvnc.exe" %WINVNC_EXE% 1>NUL:
REM
start "WinVNC" %WINVNC_EXE%
REM
call :sleepSecs 3
%WINVNC_EXE% -connect %TGT_IP%:%TGT_PORT%
REM
goto :eof


:downloadUltraVNC
REM
SET ULTRAVNC_ZIP="%TEMP%\ultravnc.zip"
REM
IF NOT EXIST %ULTRAVNC_ZIP% call :logAdd "[INFO] Die Anwendung wird heruntergeladen ..." & call :psDownloadFile %URL_ULTRAVNC_ZIP% %ULTRAVNC_ZIP%
IF NOT EXIST %ULTRAVNC_ZIP% call :logAdd "[ERROR] Downloadfehler, code #1." & goto :eof
call :getFileSize %ULTRAVNC_ZIP% FILE_SIZE
IF "%FILE_SIZE%" == "" call :logAdd "[ERROR] Downloadfehler, code #2." & goto :eof
IF %FILE_SIZE% LSS 5242880 call :logAdd "[ERROR] Downloadfehler, code #3." & DEL /F /Q %ULTRAVNC_ZIP% 2>NUL: & goto :eof
REM
MD "%TEMP%\ultravnc" 2>NUL:
call :psExpandArchive %ULTRAVNC_ZIP% "%TEMP%\ultravnc"
DEL /F /Q %ULTRAVNC_ZIP% 2>NUL:
copy /y "%TEMP%\ultravnc\x64\winvnc.exe" %WINVNC_EXE% 1>NUL:
RD /S /Q "%TEMP%\ultravnc" 2>NUL:
REM
goto :eof


:getFileSize
REM 
REM Get file size to variable defined in parameter #2.
SET %~2=%~z1
REM 
goto :eof


:killService
taskkill /f /im winvnc.exe >NUL: 2>&1
goto :eof


:launchWatchdog
REM
REM start /min "sessionWatchdog" cmd /c "%~dpnx0" /sessionWatchdog
REM
SET ULTRAVNC_VBS="%TEMP%\ultravnc.vbs"
REM
REM 0: hide window, 1: show window
powershell -ExecutionPolicy "ByPass" Write-Host 'CreateObject(\"Wscript.Shell\").Run Chr(34) ^& WScript.Arguments(0) ^& Chr(34) ^& \" \" ^& WScript.Arguments(1), 0, False' > %ULTRAVNC_VBS%
start "sessionWatchdog" wscript %ULTRAVNC_VBS% "%~dpnx0" /sessionWatchdog
call :sleepSecs 1
DEL /F /Q %ULTRAVNC_VBS% 2>NUL:
REM
goto :eof


:missingElevation 
REM
call :logAdd "[WARN] Die Ferneinwahl kann nicht auf administrative Rechte zurückgreifen."
IF %cd:~-1%==\ SET cd=%cd:~0,-1%
powershell "Start-Process -FilePath \"%~dpnx0\" -ArgumentList "%cd%" -verb runas" >NUL: 2>&1
REM
goto :eof


:psDownloadFile
REM 
SET TMP_URL_TO_DOWNLOAD=%1
IF DEFINED TMP_URL_TO_DOWNLOAD SET TMP_URL_TO_DOWNLOAD="%TMP_URL_TO_DOWNLOAD:"=%
REM 
SET TMP_TARGET_FILENAME=%2
IF DEFINED TMP_TARGET_FILENAME SET TMP_TARGET_FILENAME="%TMP_TARGET_FILENAME:"=%
REM 
powershell -ExecutionPolicy "ByPass" "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (new-object System.Net.WebClient).DownloadFile('%TMP_URL_TO_DOWNLOAD%','%TMP_TARGET_FILENAME%')"
REM 
goto :eof


:psExpandArchive
REM 
SET TMP_ARCHIVE_FULLFN=%1
IF DEFINED TMP_ARCHIVE_FULLFN SET TMP_ARCHIVE_FULLFN="%TMP_ARCHIVE_FULLFN:"=%
REM 
SET TMP_TARGET_FOLDER=%2
IF DEFINED TMP_TARGET_FOLDER SET TMP_TARGET_FOLDER="%TMP_TARGET_FOLDER:"=%
REM 
powershell -ExecutionPolicy "ByPass" "Expand-Archive '%TMP_ARCHIVE_FULLFN%' -DestinationPath '%TMP_TARGET_FOLDER%' -Force"
REM 
goto :eof


:sessionWatchdogInit
REM
color 5F
title %~n0 - sessionWatchdog
call :logAdd "[INFO] sessionWatchdog initialized."
REM
SET VNC_CONNECTED=0
goto :sessionWatchdog


:sessionWatchdog
REM
call :sleepSecs 5
tasklist | findstr "winvnc.exe" >NUL: 2>&1 || (call :logAdd "[INFO] sessionWatchdog: winvnc.exe exited." & goto :eof)
netstat -n | findstr "TCP" | findstr ":%TGT_PORT%" | findstr /c:"HERGESTELLT" /c:"ESTABLISHED" >NUL: 2>&1 && goto :sessionWatchdogConnected
REM
IF "%VNC_CONNECTED%" == "1" call :logAdd "[WARN] Die Sitzung wurde getrennt. Wiederverbindungsversuch ..."
SET VNC_CONNECTED=0
call :connectSession
goto :sessionWatchdog
:sessionWatchdogConnected
IF "%VNC_CONNECTED%" == "0" call :logAdd "[INFO] Die Sitzung wurde verbunden."
SET VNC_CONNECTED=1
goto :sessionWatchdog


:sleepSecs
REM 
REM Syntax:
REM 	call :sleepSecs [SECONDS_TO_SLEEP]
REM 
where sleep /q || (timeout /nobreak %1 > NUL: & goto :eof)
sleep %1
REM 
goto :eof


:writeConfig
REM
for /f "tokens=1 delims=:" %%a in ('findstr /n /b "REM StartINI" "%~f0"') do set ln=%%a
(for /f "usebackq skip=%ln% delims=" %%a in ("%~f0") do call echo %%a) > %ULTRAVNC_INI%
REM
goto :eof


StartINI
[Permissions]
[admin]
FileTransferEnabled=1
FTUserImpersonation=0
BlankMonitorEnabled=1
BlankInputsOnly=0
DefaultScale=1
UseDSMPlugin=0
DSMPlugin=
primary=1
secondary=0
SocketConnect=0
HTTPConnect=0
AutoPortSelect=0
PortNumber=25900
HTTPPortNumber=25901
InputsEnabled=1
LocalInputsDisabled=0
IdleTimeout=0
EnableJapInput=0
EnableUnicodeInput=0
EnableWin8Helper=0
QuerySetting=2
QueryTimeout=10
QueryDisableTime=0
QueryAccept=0
MaxViewerSetting=1
MaxViewers=128
Collabo=0
Frame=0
Notification=0
OSD=0
NotificationSelection=0
LockSetting=0
RemoveWallpaper=0
RemoveEffects=1
RemoveFontSmoothing=0
DebugMode=0
Avilog=0
path=.
DebugLevel=0
AllowLoopback=0
LoopbackOnly=0
AllowShutdown=1
AllowProperties=0
AllowInjection=0
AllowEditClients=1
FileTransferTimeout=30
KeepAliveInterval=5
IdleInputTimeout=0
DisableTrayIcon=1
rdpmode=0
noscreensaver=0
Secure=0
MSLogonRequired=0
NewMSLogon=0
ReverseAuthRequired=0
ConnectPriority=0
service_commandline=
accept_reject_mesg=
cloudServer=
cloudEnabled=0
[UltraVNC]
passwd=0930DCA5DFAA9A3815
passwd2=0930DCA5DFAA9A3815

[poll]
TurboMode=1
PollUnderCursor=0
PollForeground=0
PollFullScreen=1
OnlyPollConsole=0
OnlyPollOnEvent=0
MaxCpu2=100
MaxFPS=25
EnableDriver=1
EnableHook=1
EnableVirtual=0
autocapt=1
