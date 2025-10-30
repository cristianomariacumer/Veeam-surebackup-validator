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

# Kerberos Test Script - Tests if Kerberos credentials are valid

# Initialize variables
username=""
password=""
realm=""
kdc=""
keytab=""
test_service=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --username=*)
      username="${1#*=}"
      shift
      ;;
    --password=*)
      password="${1#*=}"
      shift
      ;;
    --realm=*)
      realm="${1#*=}"
      shift
      ;;
    --kdc=*)
      kdc="${1#*=}"
      shift
      ;;
    --keytab=*)
      keytab="${1#*=}"
      shift
      ;;
    --test-service=*)
      test_service="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown parameter: $1" >&2
      echo "Usage: kerberos_test.sh --username=user --password=pass --realm=EXAMPLE.COM [--kdc=kdc.example.com] [--keytab=/path/to/keytab] [--test-service=host/server.example.com]" >&2
      exit 1
      ;;
  esac
done

# Check for required Kerberos tools
if ! command -v kinit &> /dev/null; then
  echo "Error: 'kinit' command not found. Please install Kerberos client tools." >&2
  echo "  For Debian/Ubuntu: apt-get install krb5-user" >&2
  echo "  For RedHat/CentOS: yum install krb5-workstation" >&2
  exit 2
fi

# Check if either username+password or keytab is provided
if [ -z "$keytab" ] && ([ -z "$username" ] || [ -z "$password" ]); then
  echo "Error: Either username and password OR keytab must be provided" >&2
  exit 1
fi

# Check if realm is provided
if [ -z "$realm" ]; then
  echo "Error: Kerberos realm is required" >&2
  exit 1
fi

# Create temporary Kerberos config if KDC is specified
if [ -n "$kdc" ]; then
  echo "Using specified KDC: $kdc"
  KRB5_CONFIG=$(mktemp)
  cat > "$KRB5_CONFIG" << EOF
[libdefaults]
  default_realm = ${realm}

[realms]
  ${realm} = {
    kdc = ${kdc}
  }
EOF
  export KRB5_CONFIG
  echo "Created temporary Kerberos configuration at $KRB5_CONFIG"
fi

# Create a temporary Kerberos credential cache
KRB5CCNAME=$(mktemp -u)
export KRB5CCNAME
echo "Using credential cache: $KRB5CCNAME"

# Create a temporary file for the password
if [ -n "$password" ]; then
  PASSWORD_FILE=$(mktemp)
  echo "$password" > "$PASSWORD_FILE"
  chmod 600 "$PASSWORD_FILE"
fi

echo "Testing Kerberos authentication for realm: $realm"

# Try to obtain a ticket
if [ -n "$keytab" ]; then
  # Using keytab authentication
  echo "Authenticating with keytab: $keytab"
  principal="${username:-$(klist -k "$keytab" | tail -n 1 | awk '{print $2}')}"
  if [ -z "$principal" ]; then
    echo "Error: Could not determine principal from keytab" >&2
    rm -f "$KRB5_CONFIG" 2>/dev/null
    exit 3
  fi

  echo "Using principal: $principal"
  kinit -k -t "$keytab" "$principal" 2>&1
  KINIT_RESULT=$?
else
  # Using password authentication
  echo "Authenticating with username: $username"
  if [ -n "$realm" ] && [[ "$username" != *"@"* ]]; then
    principal="${username}@${realm}"
  else
    principal="${username}"
  fi

  cat "$PASSWORD_FILE" | kinit "$principal" 2>&1
  KINIT_RESULT=$?
  rm -f "$PASSWORD_FILE" 2>/dev/null
fi

# Check if authentication was successful
if [ $KINIT_RESULT -ne 0 ]; then
  echo "Error: Failed to authenticate with Kerberos" >&2
  rm -f "$KRB5_CONFIG" 2>/dev/null
  exit 3
fi

echo "Successfully obtained Kerberos ticket"

# Display ticket information
echo "Ticket information:"
klist

# Test using a service if specified
if [ -n "$test_service" ]; then
  echo "Testing access to service: $test_service"
  kvno "$test_service" 2>&1
  if [ $? -ne 0 ]; then
    echo "Warning: Could not verify service ticket for $test_service" >&2
  else
    echo "Successfully obtained service ticket for $test_service"
  fi
fi

# Cleanup
if [ -n "$kdc" ]; then
  rm -f "$KRB5_CONFIG" 2>/dev/null
fi

# Destroy the ticket
kdestroy
echo "Kerberos test completed successfully"
exit 0