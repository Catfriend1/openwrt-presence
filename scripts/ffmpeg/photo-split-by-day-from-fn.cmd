@echo off
setlocal enabledelayedexpansion
chcp 65001 >NUL:
REM
cd /d "%~dps0"
SET PATH=%PATH%;%ProgramFiles%\ffmpeg\bin
REM
REM Notes.
REM 	If your video files use the prefix IMG_ copy and replace PXL_ with IMG_ here.
REM
REM Consts.
SET MOVE_FILES_TO_SUBFOLDERS=1
SET MERGE_MP4_FILES=1
SET REENCODE_VIDEO=1
SET ANALYSE_LOGS=1
REM
REM SET REENCODE_QUALITY=28
SET REENCODE_QUALITY=30
REM
REM SET REENCODE_SCALE=hd1080
SET REENCODE_SCALE=hd720
REM
IF "%REENCODE_VIDEO%" == "0" SET "FFMPEG_STREAM_MODE=-vcodec copy -acodec copy"
IF NOT "%REENCODE_VIDEO%" == "0" SET "FFMPEG_STREAM_MODE=-filter:v "scale=%REENCODE_SCALE%,fps=30" -c:v libx265 -vtag hvc1 -crf %REENCODE_QUALITY% -c:a aac -b:a 192k"
REM MP3
REM 	-c:a libmp3lame -b:a 192k
REM
REM Check prerequisites.
where ffmpeg >NUL 2>&1 || (echo [ERROR] ffmpeg not found. & pause & goto :eof)
REM
SET "SOURCE_FOLDER=%~dps0"
SET "TARGET_FOLDER=%SOURCE_FOLDER%"
REM
IF NOT EXIST "%TARGET_FOLDER%" MD %TARGET_FOLDER% 2>NUL:
IF "%MOVE_FILES_TO_SUBFOLDERS%" == "1" call :moveFilesToSubFolders
REM
IF "%MERGE_MP4_FILES%" == "1" call :handleSubDirs
REM
IF "%ANALYSE_LOGS%" == "1" echo. & call :analyseLogs 
REM
pause
REM timeout 3
goto :eof


:analyseLogs
echo [INFO] analyseLogs
grep -l -i "error" *.log > "files-with-errors.txt"
TYPE "files-with-errors.txt" 2>NUL:
goto :eof


:handleSubDirs
REM
REM Called By:
REM 	MAIN
REM
FOR /F "delims=" %%A in ('DIR /B /AD "%SOURCE_FOLDER%\"') DO call :handleSubDirMerge %%A
REM
goto :eof


:handleSubDirMerge
REM
REM Called By:
REM 	handleSubDirs
REM
REM Variables.
SET "HSDM_DIR=%1"
REM echo [DEBUG] handleSubDirMerge: [%HSDM_DIR%]
REM
SET "TARGET_MERGED_MP4_FULLFN=%SOURCE_FOLDER%%1.mp4"
SET "TARGET_MERGED_LOG_FULLFN=%SOURCE_FOLDER%%1.log"
DEL /F "%TARGET_MERGED_MP4_FULLFN%" 2>NUL:
IF EXIST "%TARGET_MERGED_MP4_FULLFN%" echo [ERROR] File already exists: %TARGET_MERGED_MP4_FULLFN% & pause & goto :eof
REM
echo [INFO] Merging dir [%HSDM_DIR%] into [%TARGET_MERGED_MP4_FULLFN%] ...
(FOR /R %%A IN (%HSDM_DIR%\*.mp4) DO @ECHO file '%%A') | sort | ffmpeg -loglevel error -protocol_whitelist file,pipe -f concat -safe 0 -i pipe: %FFMPEG_STREAM_MODE% "%TARGET_MERGED_MP4_FULLFN%" > %TARGET_MERGED_LOG_FULLFN% 2>&1
SET FFMPEG_ERRORLEVEL=%ERRORLEVEL%
REM
IF NOT "%FFMPEG_ERRORLEVEL%" == "0" echo [ERROR] ffmpeg FAILED, code #%FFMPEG_ERRORLEVEL%.
TYPE %TARGET_MERGED_LOG_FULLFN% 2>NUL: | findstr /i "error" >NUL: && call :typeLoggedFirstErrors %TARGET_MERGED_LOG_FULLFN%
IF NOT "%FFMPEG_ERRORLEVEL%" == "0" echo [ERROR] ffmpeg FAILED, code #%FFMPEG_ERRORLEVEL%. >> %TARGET_MERGED_LOG_FULLFN%
REM
goto :eof


:moveFilesToSubFolders
REM
echo [INFO] moveFilesToSubFolders
FOR /F "delims=" %%A in ('DIR /B "%SOURCE_FOLDER%\*.*" 2^>NUL:') DO call :moveFilesToSubFoldersHandleFile %%A
REM
goto :eof


:moveFilesToSubFoldersHandleFile
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
SET "HF_CLEANED_FILENAME=%HF_FILENAME:PXL_=%"
SET "DATE_YYMMDD=!HF_CLEANED_FILENAME:~0,8!"
REM
SET "TARGET_SUB_FOLDER=%TARGET_FOLDER%PXL_!DATE_YYMMDD!"
IF NOT EXIST "%TARGET_SUB_FOLDER%" IF "%MOVE_FILES_TO_SUBFOLDERS%" == "1" MD "%TARGET_SUB_FOLDER%" 2>NUL:
REM
IF "%MOVE_FILES_TO_SUBFOLDERS%" == "1" MOVE "%SOURCE_FOLDER%\!HF_FILENAME!" "%TARGET_SUB_FOLDER%"
IF NOT "%MOVE_FILES_TO_SUBFOLDERS%" == "1" echo MOVE "%SOURCE_FOLDER%\!HF_FILENAME!" "%TARGET_SUB_FOLDER%"
REM
goto :eof


:typeLoggedFirstErrors
for /f "tokens=1-10 delims=" %%A in (%1) do (
	echo %%A
)
goto :eof
