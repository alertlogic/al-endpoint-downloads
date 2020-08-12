@echo off

setlocal enabledelayedexpansion

goto:checkPermissions

:checkPermissions
echo Administrative permissions required. Detecting permissions...
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if %errorLevel% == 0 (
    echo Success: Administrative permissions confirmed.
    call :uninstall Barkly , BarklyLogo.ico , barkly
    call :uninstall "Alert Logic" , AlertLogicLogo.ico , alep
    goto :end
) else (
    echo Failure: Please run this script with administrative permissions.
    EXIT /B 1
)

:uninstall

setlocal enabledelayedexpansion

set NAME=%~1
set ICOFILE=%~2
set SERVICEPREFIX=%~3

reg Query "HKLM\Hardware\Description\System\CentralProcessor\0" | %SYSTEMROOT%\system32\find.exe /i "x86" > NUL && set OS=32BIT || set OS=64BIT

if %OS%==32BIT set INSTALLDIR=%PROGRAMFILES%\%NAME%
if %OS%==64BIT set INSTALLDIR=%PROGRAMFILES(X86)%\%NAME%

FOR /f "tokens=2" %%A IN ('sc query type^= service state^= all ^| %SYSTEMROOT%\system32\find.exe /i "SERVICE_NAME: %SERVICEPREFIX%"') DO (
    SET SERVICE_NAME=%%A

    echo **** Stopping service !SERVICE_NAME! ****
    sc config !SERVICE_NAME! start= disabled
    sc stop !SERVICE_NAME!

    echo **** Removing RapidVisor service ****
    sc delete !SERVICE_NAME!

    echo Removing HKLM\SYSTEM\ControlSet001\services\!SERVICE_NAME!
    reg delete "HKLM\SYSTEM\ControlSet001\services\!SERVICE_NAME!" /f

    echo Removing HKLM\SYSTEM\ControlSet002\services\!SERVICE_NAME!
    reg delete "HKLM\SYSTEM\ControlSet002\services\!SERVICE_NAME!" /f

    echo Removing HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\eventlog\Application\Barkly RapidVisor
    reg delete "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\eventlog\Application\Barkly RapidVisor" /f
    echo Removing HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\eventlog\Application\!SERVICE_NAME!
    reg delete "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\eventlog\Application\!SERVICE_NAME!" /f

    echo Removing HKEY_LOCAL_MACHINE\SYSTEM\ControlSet002\services\eventlog\Application\Barkly RapidVisor
    reg delete "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet002\services\eventlog\Application\Barkly RapidVisor" /f
    echo Removing HKEY_LOCAL_MACHINE\SYSTEM\ControlSet002\services\eventlog\Application\!SERVICE_NAME!
    reg delete "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet002\services\eventlog\Application\!SERVICE_NAME!" /f
)

set DRIVERS=boscmflt bospsflt bosfsflt bosincidentflt Illuminate RV-OSMonitor RapidVisor

echo **** Stopping Drivers ****
for %%b in (%DRIVERS%) do (
  sc stop %%b
)

echo **** Removing Drivers ****
for %%b in (%DRIVERS%) do (
  set DRIVER=%%b
  sc delete !DRIVER!
  echo Removing HKLM\SYSTEM\ControlSet001\services\!DRIVER!
  reg delete "HKLM\SYSTEM\ControlSet001\services\!DRIVER!" /f
  echo Removing HKLM\SYSTEM\ControlSet002\services\!DRIVER!
  reg delete "HKLM\SYSTEM\ControlSet002\services\!DRIVER!" /f
)


echo **** Removing Registry Keys ****
for /f "delims=" %%i in ('REG QUERY HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall /F "%NAME% Endpoint Protection" /D /S ^| FINDSTR /R /B /C:"HKEY_"') do echo %%i & reg delete %%i /f

for /f "delims=" %%i in ('REG QUERY HKCR\Installer\Products /F "%ICOFILE%" /D /S ^| FINDSTR /R /B /C:"HKEY_"') do echo %%i & reg delete %%i /f

for /f "delims=" %%i in ('REG QUERY HKLM\SOFTWARE\Classes\Installer\Products /F "%ICOFILE%" /D /S ^| FINDSTR /R /B /C:"HKEY_"') do echo %%i & reg delete %%i /f

for /f "delims=" %%i in ('REG QUERY HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products /F "%NAME% Endpoint Protection" /D /S ^| FINDSTR /R /B /C:"HKEY_"') do echo %%i & reg delete %%i /f

for /f "delims=" %%i in ('REG QUERY HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Components /F "%INSTALLDIR%" /D /S ^| FINDSTR /R /B /C:"HKEY_"') do echo %%i & reg delete %%i /f

for /f "delims=" %%i in ('REG QUERY HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Components /F "%NAME%\Extended Endpoint Protection" /D /S ^| FINDSTR /R /B /C:"HKEY_"') do echo %%i & reg delete %%i /f

for /f "delims=" %%a in (
  'REG QUERY HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\Folders /v "*%INSTALLDIR%*" ^| findstr /I /C:"REG_SZ"'
) do (
  REM Trim leading whitespace
  for /f "tokens=* delims= " %%b in ("%%a") do set "Value=%%b"

  REM Truncate REG_SZ portion of reg query output
  set "Value=!Value:    REG_SZ=@!"

  for /f "delims=@" %%b in ("!Value!") do (
    echo Removing registry value: %%b
    reg delete HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\Folders /v "%%b\" /f
  )
)

echo Removing HKEY_LOCAL_MACHINE\SOFTWARE\Barkly
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Barkly" /f

echo Removing HKEY_LOCAL_MACHINE\SOFTWARE\Alert Logic\Extended Endpoint Protection
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Alert Logic\Extended Endpoint Protection" /f

echo **** Removing System Files ****
SET DRIVER_LIST=RapidVisor.sys boscmflt.sys bosfsflt.sys bosincidentflt.sys BOsMonDLL.sys BOsMonRuleDLL.sys bospsflt.sys Illuminate.sys VMI.sys RV-OSMonitor.sys
FOR %%a in (%DRIVER_LIST%) DO (
    echo Removing file %SYSTEMROOT%\System32\drivers\%%a
    IF EXIST %SYSTEMROOT%\System32\drivers\%%a del /F %SYSTEMROOT%\System32\drivers\%%a
)

rem List information on all third-party INF files
for /F "tokens=2* delims=:" %%a in ('pnputil -e') do (
    rem Separate and remove spaces within values
    for /f "tokens=1 delims= " %%d in ("%%a") do (
        if not %%d==RapidVisor (
            set tempINF=%%d
        )
        if %%d==RapidVisor (
            echo Removing RapidVisor driver package under the Published Name: !tempINF!
            pnputil -f -d !tempINF!
        )
    )
)

echo **** Removing UpgradeCodes ****
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UpgradeCodes\1612EF76BAB35514E98E24FD27E16433" /f
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Installer\UpgradeCodes\1612EF76BAB35514E98E24FD27E16433" /f

echo **** Removing Install Directory ****
IF EXIST "%INSTALLDIR%" rmdir /s /q "%INSTALLDIR%"

EXIT /B 0

:end
echo **** Finished Uninstalling ****
