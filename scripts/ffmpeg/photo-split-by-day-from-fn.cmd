@echo off
setlocal enabledelayedexpansion
chcp 65001 >NUL:
REM
cd /d "%~dps0"
SET PATH=%PATH%;%ProgramFiles%\ffmpeg\bin
REM
REM Consts.
SET MOVE_FILES_TO_SUBFOLDERS=1
SET MERGE_MP4_FILES=1
SET REENCODE_VIDEO=1
SET ANALYSE_LOGS=1
REM
IF "%REENCODE_VIDEO%" == "0" SET "FFMPEG_STREAM_MODE=-vcodec copy -acodec copy"
IF NOT "%REENCODE_VIDEO%" == "0" SET "FFMPEG_STREAM_MODE=-filter:v "scale=hd1080,fps=30" -c:v libx265 -vtag hvc1 -crf 28 -c:a aac -b:a 192k"
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
FOR /F "delims=" %%A in ('DIR /B "%SOURCE_FOLDER%\*.*" 2^>NUL:') DO call :handleFile %%A
REM
IF "%MERGE_MP4_FILES%" == "1" call :handleSubDirs
REM
echo [INFO] Collecting errors ...
IF "%ANALYSE_LOGS%" == "1" grep -l -i "error" *.log > "files-with-errors.txt" & TYPE "files-with-errors.txt" 2>NUL:
REM
pause
REM timeout 3
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
IF NOT "%FFMPEG_ERRORLEVEL%" == "0" echo [ERROR] ffmpeg FAILED, code #%FFMPEG_ERRORLEVEL%. >> %TARGET_MERGED_LOG_FULLFN%
IF NOT "%FFMPEG_ERRORLEVEL%" == "0" echo [ERROR] ffmpeg FAILED, code #%FFMPEG_ERRORLEVEL%. & goto :eof
REM
goto :eof


:moveFilesToSubFolders
REM
echo [INFO] Preparing to move files to subfolders ...
FOR /F "delims=" %%A in ('DIR /B "%SOURCE_FOLDER%\*.*" 2^>NUL:') DO call :moveFilesToSubFoldersHandleFile %%A
REM
goto :eof
