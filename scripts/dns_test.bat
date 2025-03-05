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

:: DNS Test Script - Tests if a hostname resolves to the expected IP address

setlocal enabledelayedexpansion

:: Initialize variables
set "hostname="
set "expected_ip="
set "dns_server="

:: Parse arguments
:parse_args
if "%~1"=="" goto :main
set arg=%~1
if "!arg:~0,11!"=="--hostname=" (
    set "hostname=!arg:~11!"
) else if "!arg:~0,14!"=="--expected-ip=" (
    set "expected_ip=!arg:~14!"
) else if "!arg:~0,13!"=="--dns-server=" (
    set "dns_server=!arg:~13!"
) else (
    echo Unknown parameter: %1 1>&2
    echo Usage: dns_test.bat --hostname=example.com --expected-ip=1.2.3.4 [--dns-server=8.8.8.8] 1>&2
    exit /b 1
)
shift
goto :parse_args

:main
:: Check required parameters
if "%hostname%"=="" (
    echo Error: Hostname is required 1>&2
    exit /b 1
)

if "%expected_ip%"=="" (
    echo Error: Expected IP address is required 1>&2
    exit /b 1
)

echo Testing DNS resolution for %hostname% (expected: %expected_ip%)

:: Create temporary file for nslookup output
set "temp_file=%TEMP%\dns_test_%RANDOM%.txt"

:: Perform DNS lookup
if "%dns_server%"=="" (
    :: Use default DNS server
    nslookup %hostname% > "%temp_file%" 2>&1
) else (
    :: Use specified DNS server
    nslookup %hostname% %dns_server% > "%temp_file%" 2>&1
)

:: Check if nslookup failed
findstr /C:"Non-existent domain" "%temp_file%" > nul
if %ERRORLEVEL% EQU 0 (
    echo Error: Domain %hostname% does not exist 1>&2
    del "%temp_file%" 2>nul
    exit /b 2
)

findstr /C:"can't find" "%temp_file%" > nul
if %ERRORLEVEL% EQU 0 (
    echo Error: Could not resolve %hostname% 1>&2
    del "%temp_file%" 2>nul
    exit /b 2
)

:: Extract the resolved IP address
for /f "tokens=2 delims=: " %%i in ('findstr /C:"Address" "%temp_file%" ^| findstr /V "DNS_Server"') do (
    set "resolved_ip=%%i"
    goto :check_result
)

:check_result
:: Delete temporary file
del "%temp_file%" 2>nul

:: Check if we got an IP
if "%resolved_ip%"=="" (
    echo Error: Could not extract resolved IP for %hostname% 1>&2
    exit /b 2
)

echo Resolved IP: %resolved_ip%

:: Compare with expected IP
if "%resolved_ip%"=="%expected_ip%" (
    echo Success: %hostname% resolved to expected IP %expected_ip%
    exit /b 0
) else (
    echo Error: %hostname% resolved to %resolved_ip% (expected: %expected_ip%) 1>&2
    exit /b 3
) 