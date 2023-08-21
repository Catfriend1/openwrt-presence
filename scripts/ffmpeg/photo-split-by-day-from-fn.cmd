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
pause
REM timeout 3
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
IF /I "%~x1" == ".cmd" goto :eof
REM
SET "HF_CLEANED_FILENAME=%HF_FILENAME:PXL_=%"
SET "DATE_YYMMDD=!HF_CLEANED_FILENAME:~0,8!"
REM
SET "TARGET_SUB_FOLDER=%TARGET_FOLDER%PXL_!DATE_YYMMDD!"
IF NOT EXIST "%TARGET_SUB_FOLDER%" IF "%MOVE_FILES_TO_SUBFOLDERS%" == "0" MD "%TARGET_SUB_FOLDER%" 2>NUL:
REM
IF "%MOVE_FILES_TO_SUBFOLDERS%" == "0" MOVE "%SOURCE_FOLDER%\!HF_FILENAME!" "%TARGET_SUB_FOLDER%"
IF NOT "%MOVE_FILES_TO_SUBFOLDERS%" == "0" echo MOVE "%SOURCE_FOLDER%\!HF_FILENAME!" "%TARGET_SUB_FOLDER%"
REM
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
DEL /F "%TARGET_MERGED_MP4_FULLFN%" 2>NUL:
IF EXIST "%TARGET_MERGED_MP4_FULLFN%" echo [ERROR] File already exists: %TARGET_MERGED_MP4_FULLFN% & pause & goto :eof
REM
echo [INFO] Merging dir [%HSDM_DIR%] into [%TARGET_MERGED_MP4_FULLFN%] ...
(FOR /R %%A IN (%HSDM_DIR%\*.mp4) DO @ECHO file '%%A') | sort | ffmpeg -loglevel error -protocol_whitelist file,pipe -f concat -safe 0 -i pipe: %FFMPEG_STREAM_MODE% "%TARGET_MERGED_MP4_FULLFN%"
SET FFMPEG_ERRORLEVEL=%ERRORLEVEL%
IF NOT "%FFMPEG_ERRORLEVEL%" == "0" echo [ERROR] ffmpeg FAILED, code #%FFMPEG_ERRORLEVEL%. & pause & goto :eof
REM
goto :eof
