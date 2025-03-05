@echo off
:: Copyright (C) 2025 Libera Universita' di Bolzano
::
:: This program is free software: you can redistribute it and/or modify
:: it under the terms of the European Union Public License v. 1.2, as 
:: published by the European Commission.
::
:: You should have received a copy of the EUPL v1.2 license
:: along with this program. If not, you can find it at:
:: https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12
::
:: Unless required by applicable law or agreed to in writing, software
:: distributed under the EUPL v1.2 is distributed on an "AS IS" basis,
:: WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
:: See the EUPL v1.2 for more details.

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