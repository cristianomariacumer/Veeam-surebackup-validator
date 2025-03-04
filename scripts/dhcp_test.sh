#!/bin/bash
# DHCP Test Script - Tests if DHCP is working properly on a specified interface

# Initialize variables
interface=""
timeout=30
expected_subnet=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --interface=*)
      interface="${1#*=}"
      shift
      ;;
    --timeout=*)
      timeout="${1#*=}"
      shift
      ;;
    --expected-subnet=*)
      expected_subnet="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown parameter: $1" >&2
      echo "Usage: dhcp_test.sh --interface=eth0 [--timeout=30] [--expected-subnet=192.168.1]" >&2
      exit 1
      ;;
  esac
done

# Check if root
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root" >&2
  exit 1
fi

# Check required parameters
if [ -z "$interface" ]; then
  echo "Error: Network interface is required" >&2
  exit 1
fi

# Check if interface exists
if ! ip link show "$interface" &>/dev/null; then
  echo "Error: Interface $interface does not exist" >&2
  exit 1
fi

echo "Testing DHCP on interface $interface (timeout: ${timeout}s)"

# Get initial IP configuration
initial_ip=$(ip -4 addr show dev "$interface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
if [ -n "$initial_ip" ]; then
  echo "Initial IP address: $initial_ip"
else
  echo "No initial IP address assigned"
fi

# Bring interface down and up to reset connectivity
echo "Resetting interface $interface..."
ip link set "$interface" down
sleep 2
ip link set "$interface" up
sleep 2

# Release any existing DHCP lease
if command -v dhclient &>/dev/null; then
  echo "Releasing DHCP lease..."
  dhclient -r "$interface" 2>/dev/null || true
  sleep 2
elif command -v dhcpcd &>/dev/null; then
  echo "Releasing DHCP lease..."
  dhcpcd -k "$interface" 2>/dev/null || true
  sleep 2
fi

# Request a new DHCP lease
echo "Requesting a new DHCP lease (timeout: ${timeout}s)..."
if command -v dhclient &>/dev/null; then
  timeout "$timeout" dhclient -v "$interface" 2>&1 | grep -i "bound to\|DHCPACK"
  dhcp_result=$?
elif command -v dhcpcd &>/dev/null; then
  timeout "$timeout" dhcpcd -t "$timeout" "$interface" 2>&1 | grep -i "offered\|leased"
  dhcp_result=$?
else
  echo "Error: No DHCP client found (dhclient or dhcpcd required)" >&2
  exit 2
fi

# Check if DHCP request succeeded
if [ $dhcp_result -ne 0 ]; then
  echo "Error: Failed to obtain DHCP lease" >&2
  exit 3
fi

# Get the newly assigned IP address
sleep 2
new_ip=$(ip -4 addr show dev "$interface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if [ -z "$new_ip" ]; then
  echo "Error: No IP address assigned after DHCP request" >&2
  exit 3
fi

echo "New IP address: $new_ip"

# Check if IP is in the expected subnet (if provided)
if [ -n "$expected_subnet" ]; then
  if [[ "$new_ip" == $expected_subnet* ]]; then
    echo "IP address is within expected subnet $expected_subnet"
  else
    echo "Error: IP address $new_ip is not in the expected subnet $expected_subnet" >&2
    exit 4
  fi
fi

# Get the default gateway
gateway=$(ip route | grep default | grep "$interface" | awk '{print $3}')
if [ -n "$gateway" ]; then
  echo "Default gateway: $gateway"
  
  # Test connectivity to the gateway
  echo "Testing connectivity to gateway..."
  if ping -c 3 -W 2 "$gateway" &>/dev/null; then
    echo "Successfully pinged gateway"
  else
    echo "Warning: Could not ping gateway $gateway" >&2
  fi
else
  echo "Warning: No default gateway found" >&2
fi

# Get the DNS servers from /etc/resolv.conf
echo "DNS servers:"
grep nameserver /etc/resolv.conf | awk '{print $2}'

# Test internet connectivity
echo "Testing internet connectivity..."
if ping -c 3 -W 5 8.8.8.8 &>/dev/null; then
  echo "Internet connectivity: OK"
else
  echo "Warning: No internet connectivity" >&2
fi

# Test DNS resolution
echo "Testing DNS resolution..."
if host google.com &>/dev/null; then
  echo "DNS resolution: OK"
else
  echo "Warning: DNS resolution failed" >&2
fi

# Report success
echo "DHCP test completed successfully"
exit 0 