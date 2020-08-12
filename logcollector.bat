@echo off

:START

set INPUT=y
echo To help us figure out the problem we would like to 
echo collect some system information
echo.
set /P INPUT="Is this okay (Y/N)? (default=Y):"

If /I "%INPUT%"=="y" GOTO:YES
If /I "%INPUT%"=="n" GOTO:EOF
echo.
echo.
echo Sorry, you must answer Y or N
GOTO:START


:YES
echo Thanks! This might take a few minutes
echo.
:RETRY_DIR

for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set timestamp=%%j
set timestamp=%timestamp:~0,4%-%timestamp:~4,2%-%timestamp:~6,2%_%timestamp:~8,2%-%timestamp:~10,2%-%timestamp:~12,2%
set targetDir=barkly_%timestamp%

IF EXIST %targetDir% GOTO:RETRY_DIR
echo Creating directory %targetDir%
mkdir %targetDir%
mkdir %targetDir%\daemon
mkdir %targetDir%\logs
mkdir %targetDir%\config
mkdir %targetDir%\Minidump

IF NOT EXIST "%WINDIR%\Temp\barklyUpgrade.log" GOTO:SKIP_UPGRADE_LOG
echo Copying the barkly upgrade log
xcopy "%WINDIR%\Temp\barklyUpgrade.log" %targetDir%
:SKIP_UPGRADE_LOG

IF NOT EXIST "%WINDIR%\MEMORY.DMP" GOTO:SKIP_MEMORY_DUMP
echo Copying the memory dump
xcopy "%WINDIR%\MEMORY.DMP" %targetDir%
:SKIP_MEMORY_DUMP

IF NOT EXIST "%WINDIR%\Minidump" GOTO:SKIP_MINI_MEMORY_DUMP
echo Copying the mini memory dump
xcopy /s/e "%WINDIR%\Minidump" %targetDir%\Minidump
:SKIP_MINI_MEMORY_DUMP

reg Query "HKLM\Hardware\Description\System\CentralProcessor\0" | find /i "x86" > NUL && set OS=32BIT || set OS=64BIT
if %OS%==32BIT set programFilesDir=%PROGRAMFILES%
if %OS%==64BIT set programFilesDir=%PROGRAMFILES(X86)%

IF NOT EXIST "%programFilesDir%\Barkly\daemon" GOTO:SKIP_DEAMON_LOGS
echo Copying daemon logs
xcopy /s/e "%programFilesDir%\Barkly\daemon" %targetDir%\daemon
:SKIP_DEAMON_LOGS

IF NOT EXIST "%programFilesDir%\Barkly\logs" GOTO:SKIP_BARKLY_LOGS
echo Copying barkly logs
xcopy /s/e "%programFilesDir%\Barkly\logs" %targetDir%\logs
:SKIP_BARKLY_LOGS

IF NOT EXIST "%programFilesDir%\Barkly\config" GOTO:SKIP_BARKLY_CONFIGS
echo Copying barkly configs
xcopy /s/e "%programFilesDir%\Barkly\config" %targetDir%\config
:SKIP_BARKLY_CONFIGS

echo Generating system report
msinfo32 /report %targetDir%\msinfo-report.txt

echo Saving System Log
wevtutil.exe epl System %targetDir%\System.evtx

echo Saving Application Log
wevtutil.exe epl Application %targetDir%\Application.evtx


echo.
echo.
echo Everything has been copied to the folder %targetDir%.
echo If you could zip that up and send it to Barkly we would
echo greatly appreciate it.  Thanks for helping us!
echo.
echo Press any key to exit.
pause > nul
