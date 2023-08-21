@echo off
setlocal enabledelayedexpansion
chcp 65001 >NUL:
REM
cd /d "%~dps0"
SET PATH=%PATH%;%ProgramFiles%\ffmpeg\bin
REM
del "merged.mp4" 2> NUL:
IF EXIST "merged.mp4" echo [ERROR] Stop, target file exists. & pause & goto :eof
REM
(FOR /R %%A IN (*.mp4) DO @ECHO file '%%A') | ffmpeg -protocol_whitelist file,pipe -f concat -safe 0 -i pipe: -vcodec copy -acodec copy "merged.mp4"
REM
timeout 3
REM
goto :eof
