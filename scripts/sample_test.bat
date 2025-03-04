@echo off
:: Sample test script for Windows

setlocal enabledelayedexpansion

:: Parse arguments
set message=Hello from sample test script!
set fail=false

:parse_args
if "%~1"=="" goto :main
set arg=%~1
if "!arg:~0,10!"=="--message=" (
    set message=!arg:~10!
) else if "!arg:~0,7!"=="--fail=" (
    set fail=!arg:~7!
) else (
    echo Unknown parameter: %1 1>&2
    exit /b 1
)
shift
goto :parse_args

:main
:: Check if should fail
if "%fail%"=="true" (
    echo Error: Script failed as requested 1>&2
    exit /b 1
)

:: Output message and exit successfully
echo %message%
exit /b 0 