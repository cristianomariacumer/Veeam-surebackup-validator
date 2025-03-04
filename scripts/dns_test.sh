#!/bin/bash
# DNS Test Script - Tests if a hostname resolves to the expected IP address

# Initialize variables
hostname=""
expected_ip=""
dns_server=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --hostname=*)
      hostname="${1#*=}"
      shift
      ;;
    --expected-ip=*)
      expected_ip="${1#*=}"
      shift
      ;;
    --dns-server=*)
      dns_server="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown parameter: $1" >&2
      echo "Usage: dns_test.sh --hostname=example.com --expected-ip=1.2.3.4 [--dns-server=8.8.8.8]" >&2
      exit 1
      ;;
  esac
done

# Check required parameters
if [ -z "$hostname" ]; then
  echo "Error: Hostname is required" >&2
  exit 1
fi

if [ -z "$expected_ip" ]; then
  echo "Error: Expected IP address is required" >&2
  exit 1
fi

echo "Testing DNS resolution for $hostname (expected: $expected_ip)"

# Perform DNS lookup
if [ -z "$dns_server" ]; then
  # Use default DNS server
  resolved_ip=$(dig +short "$hostname" A | grep -v ";" | head -n 1)
  
  # If dig isn't available, try nslookup
  if [ -z "$resolved_ip" ]; then
    resolved_ip=$(nslookup "$hostname" 2>/dev/null | awk '/^Address: / { print $2 }' | grep -v ":" | head -n 2 | tail -n 1)
  fi
  
  # If nslookup isn't available either, try host
  if [ -z "$resolved_ip" ]; then
    resolved_ip=$(host "$hostname" 2>/dev/null | awk '/has address/ { print $4 }' | head -n 1)
  fi
else
  # Use specified DNS server
  resolved_ip=$(dig +short "$hostname" A @"$dns_server" | grep -v ";" | head -n 1)
  
  # If dig isn't available, try nslookup
  if [ -z "$resolved_ip" ]; then
    resolved_ip=$(nslookup "$hostname" "$dns_server" 2>/dev/null | awk '/^Address: / { print $2 }' | grep -v ":" | tail -n 1)
  fi
  
  # If nslookup isn't available either, try host
  if [ -z "$resolved_ip" ]; then
    resolved_ip=$(host "$hostname" "$dns_server" 2>/dev/null | awk '/has address/ { print $4 }' | head -n 1)
  fi
fi

# Check if resolution was successful
if [ -z "$resolved_ip" ]; then
  echo "Error: Could not resolve $hostname" >&2
  exit 2
fi

echo "Resolved IP: $resolved_ip"

# Compare with expected IP
if [ "$resolved_ip" = "$expected_ip" ]; then
  echo "Success: $hostname resolved to expected IP $expected_ip"
  exit 0
else
  echo "Error: $hostname resolved to $resolved_ip (expected: $expected_ip)" >&2
  exit 3
fi 