@echo off
setlocal enabledelayedexpansion
chcp 65001 >NUL:
REM
cd /d "%~dps0"
SET PATH=%PATH%;%ProgramFiles%\ffmpeg\bin
REM
REM Notes.
REM
REM Consts.
SET REENCODE_QUALITY=30
REM SET REENCODE_QUALITY=32
REM
REM SET REENCODE_SCALE=1920:1080
SET REENCODE_SCALE=1280:720
REM
SET "FFMPEG_STREAM_MODE= -filter:v "scale=%REENCODE_SCALE%:force_original_aspect_ratio=decrease,pad=%REENCODE_SCALE%:-1:-1:color=black,fps=30" -c:v libx265 -vtag hvc1 -crf %REENCODE_QUALITY% -c:a aac -b:a 192k"
REM MP3
REM 	-c:a libmp3lame -b:a 192k
REM
REM Check prerequisites.
where ffmpeg >NUL 2>&1 || (echo [ERROR] ffmpeg not found. & pause & goto :eof)
REM
SET "SOURCE_FOLDER=%~dps0"
SET "TARGET_OUTPUT_FOLDER_NAME=_output"
SET "TARGET_OUTPUT_FOLDER=%~dps0%TARGET_OUTPUT_FOLDER_NAME%"
REM
MD "%TARGET_OUTPUT_FOLDER%" 2>NUL:
REM
call :handleFiles
REM
pause
REM
goto :eof


:handleFiles
REM
echo [INFO] handleFiles
FOR /F "delims=" %%A in ('DIR /B "%SOURCE_FOLDER%\*.*" 2^>NUL:') DO call :handleFile %%A
REM
goto :eof


:handleFile
REM
REM Called By:
REM 	MAIN
REM
REM Variables.
SET "HF_FILENAME=%1"
REM
REM Skip unsupported file types.
IF /I "%~x1" == "" goto :eof
IF /I "%~x1" == ".cmd" goto :eof
IF /I "%~x1" == ".log" goto :eof
IF /I "%~x1" == ".txt" goto :eof
REM
SET "TARGET_MP4_FULLFN=%TARGET_OUTPUT_FOLDER%\%HF_FILENAME%"
SET "TARGET_LOG_FULLFN=%TARGET_OUTPUT_FOLDER%\%HF_FILENAME%.log"
DEL /F "%TARGET_MP4_FULLFN%" 2>NUL:
IF EXIST "%TARGET_MP4_FULLFN%" echo [ERROR] File already exists: %TARGET_MP4_FULLFN% & pause & goto :eof
REM
echo [INFO] Converting file [%HF_FILENAME%] ...
(@ECHO file '%SOURCE_FOLDER%\%HF_FILENAME%') | ffmpeg -loglevel error -protocol_whitelist file,pipe -f concat -safe 0 -i pipe: %FFMPEG_STREAM_MODE% "%TARGET_MP4_FULLFN%" > "%TARGET_LOG_FULLFN%" 2>&1
SET FFMPEG_ERRORLEVEL=%ERRORLEVEL%
REM
REM In case of ERROR.
IF NOT "%FFMPEG_ERRORLEVEL%" == "0" echo [ERROR] ffmpeg FAILED, code #%FFMPEG_ERRORLEVEL%.
TYPE "%TARGET_LOG_FULLFN%" 2>NUL: | findstr /i "error" >NUL: && call :typeLoggedFirstErrors "%TARGET_LOG_FULLFN%"
IF NOT "%FFMPEG_ERRORLEVEL%" == "0" echo [ERROR] ffmpeg FAILED, code #%FFMPEG_ERRORLEVEL%. >> "%TARGET_LOG_FULLFN%"
REM
REM In case of SUCCESS.
TYPE "%TARGET_LOG_FULLFN%" 2>NUL: | findstr /i "error" >NUL: || DEL "%TARGET_LOG_FULLFN%" 2>NUL:
REM
goto :eof


:typeLoggedFirstErrors
for /f "tokens=1-10 delims=" %%A in (%1) do (
	echo %%A
)
goto :eof
