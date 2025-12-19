@echo off
REM Stop the script if any command fails
setlocal enabledelayedexpansion

REM --- CONFIGURATION ---
set APP_NAME=boxwallet
set VERSION=0.0.5

echo Starting build for %APP_NAME% v%VERSION%...

set MIX_ENV=prod

echo Fetching dependencies...
call mix deps.get --only prod
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

echo Compiling...
call mix compile
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

echo Building assets....
call mix assets.deploy
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

echo Generating Release...
call mix release --overwrite
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

echo Compressing...
set RELEASE_DIR=_build\prod\rel\%APP_NAME%
set OUTPUT_FILE=%APP_NAME%-%VERSION%-windows-x64.zip

powershell -Command "Compress-Archive -Path '_build\prod\rel\%APP_NAME%' -DestinationPath '%OUTPUT_FILE%' -Force"
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

echo Done! Your file is ready at:
echo %CD%\%OUTPUT_FILE%
