#!/bin/bash
# Copyright (C) 2025 Libera Universita' di Bolzano
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the European Union Public License v. 1.2, as 
# published by the European Commission.
#
# You should have received a copy of the EUPL v1.2 license
# along with this program. If not, you can find it at:
# https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the EUPL v1.2 is distributed on an "AS IS" basis,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the EUPL v1.2 for more details.

# MSSQL Test Script - Executes a query using Kerberos authentication and
# compares the output against an expected value.

set -euo pipefail

keytab_path=""
kerberos_principal=""
target_host=""
target_port="1433"
query=""
expected_result=""
database_name=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --keytab=*)
      keytab_path="${1#*=}"
      shift
      ;;
    --principal=*)
      kerberos_principal="${1#*=}"
      shift
      ;;
    --host=*)
      target_host="${1#*=}"
      shift
      ;;
    --port=*)
      target_port="${1#*=}"
      shift
      ;;
    --query=*)
      query="${1#*=}"
      shift
      ;;
    --expected=*)
      expected_result="${1#*=}"
      shift
      ;;
    --database=*)
      database_name="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown parameter: $1" >&2
      echo "Usage: mssql_test.sh --keytab=/path/to/keytab [--principal=service@REALM] --host=db.example.com [--port=1433] --query=\"SELECT 1\" --expected=1" >&2
      exit 1
      ;;
  esac
done

# Validate required parameters
if [[ -z "$keytab_path" ]]; then
  echo "Error: --keytab parameter is required" >&2
  exit 1
fi
if [[ -z "$target_host" ]]; then
  echo "Error: --host parameter is required" >&2
  exit 1
fi
if [[ -z "$query" ]]; then
  echo "Error: --query parameter is required" >&2
  exit 1
fi
if [[ -z "$expected_result" ]]; then
  echo "Error: --expected parameter is required" >&2
  exit 1
fi

if [[ ! -r "$keytab_path" ]]; then
  echo "Error: Keytab file '$keytab_path' does not exist or is not readable" >&2
  exit 1
fi

if ! command -v kinit >/dev/null 2>&1; then
  echo "Error: kinit command not found (Kerberos client tools required)" >&2
  exit 1
fi

if ! command -v sqlcmd >/dev/null 2>&1; then
  echo "Error: sqlcmd command not found (Microsoft ODBC Driver / mssql-tools package required)" >&2
  exit 1
fi

# Determine Kerberos principal if not provided explicitly
if [[ -z "$kerberos_principal" ]]; then
  if ! command -v klist >/dev/null 2>&1; then
    echo "Error: klist command not found and principal could not be auto-detected" >&2
    exit 1
  fi

  kerberos_principal=$(klist -k "$keytab_path" 2>/dev/null | awk 'NR>3 && NF {print $NF; exit}')
  if [[ -z "$kerberos_principal" ]]; then
    echo "Error: Could not determine principal from keytab. Provide it with --principal." >&2
    exit 1
  fi
fi

echo "Using principal $kerberos_principal to authenticate against $target_host:$target_port"

# Use a dedicated credential cache so we do not disturb existing tickets
ccache_path=$(mktemp /tmp/mssql_test_ccache.XXXXXX)
ticket_cache="FILE:${ccache_path}"
export KRB5CCNAME="$ticket_cache"

cleanup() {
  kdestroy -c "$ticket_cache" >/dev/null 2>&1 || true
  rm -f "$ccache_path" >/dev/null 2>&1 || true
}

trap cleanup EXIT

# Acquire Kerberos ticket
if ! kinit -k -t "$keytab_path" "$kerberos_principal" >/dev/null 2>&1; then
  echo "Error: Failed to obtain Kerberos ticket using the provided keytab" >&2
  exit 2
fi

target="$target_host"
if [[ -n "$target_port" ]]; then
  target="${target_host},${target_port}"
fi

echo "Executing query: $query"

sqlcmd_cmd=(sqlcmd -S "$target" -b -W -h -1 -C)
if [[ -n "$database_name" ]]; then
  sqlcmd_cmd+=( -d "$database_name" )
fi
sqlcmd_cmd+=( -Q "$query" )

# Execute the query; remove headers and trim whitespace for comparison
set +e
sqlcmd_output="$("${sqlcmd_cmd[@]}")"
exit_code=$?
set -e
if [[ $exit_code -ne 0 ]]; then
  echo "Error: Query execution failed" >&2
  echo "$sqlcmd_output" >&2
  exit 3
fi

# Normalize output and expected value
normalize() {
  printf '%s' "$1" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

normalized_output=$(normalize "$sqlcmd_output")
normalized_expected=$(normalize "$expected_result")

echo "Query result: $normalized_output"

if [[ "$normalized_output" == "$normalized_expected" ]]; then
  echo "Success: Query result matches expected output"
  exit 0
else
  echo "Error: Query result '$normalized_output' does not match expected '$normalized_expected'" >&2
  exit 4
fi
