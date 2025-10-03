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
      echo "Usage: dhcp_test.sh --interface=eth0 [--timeout=30] [--expected-subnet=192.168.1.0/24]" >&2
      exit 1
      ;;
  esac
done

# Check required parameters
if [ -z "$interface" ]; then
  echo "Error: Network interface is required" >&2
  exit 1
fi

# Check if interface exists
if ! sudo ip link show "$interface" &>/dev/null; then
  echo "Error: Interface $interface does not exist" >&2
  exit 1
fi

echo "Testing DHCP on interface $interface (timeout: ${timeout}s)"

# Get initial IP configuration
initial_ip=$(sudo ip -4 addr show dev "$interface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
if [ -n "$initial_ip" ]; then
  echo "Initial IP address: $initial_ip"
else
  echo "No initial IP address assigned"
fi

# Bring interface down and up to reset connectivity
echo "Resetting interface $interface..."
sudo ip link set "$interface" down
sleep 2
sudo ip link set "$interface" up
sleep 2

# Release any existing DHCP lease
if command -v dhclient &>/dev/null; then
  echo "Releasing DHCP lease..."
  sudo dhclient -r "$interface" 2>/dev/null || true
  sleep 2
elif command -v dhcpcd &>/dev/null; then
  echo "Releasing DHCP lease..."
  sudo dhcpcd -k "$interface" 2>/dev/null || true
  sleep 2
fi

# Request a new DHCP lease
echo "Requesting a new DHCP lease (timeout: ${timeout}s)..."
if command -v dhclient &>/dev/null; then
  sudo timeout "$timeout" dhclient -v "$interface" 2>&1 | grep -i "bound to\|DHCPACK"
  dhcp_result=$?
elif command -v dhcpcd &>/dev/null; then
  sudo timeout "$timeout" dhcpcd -t "$timeout" "$interface" 2>&1 | grep -i "offered\|leased"
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
new_ip=$(sudo ip -4 addr show dev "$interface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if [ -z "$new_ip" ]; then
  echo "Error: No IP address assigned after DHCP request" >&2
  exit 3
fi

echo "New IP address: $new_ip"

# Function to check if an IP address is within a subnet range
# Takes two arguments: IP address and subnet range (CIDR or netmask notation)
is_ip_in_subnet() {
  local ip="$1"
  local subnet="$2"
  
  # Check if the subnet uses CIDR notation or not
  if [[ "$subnet" == *"/"* ]]; then
    # CIDR notation (e.g., 192.168.1.0/24)
    # Use ipcalc or sipcalc if available
    if command -v ipcalc &>/dev/null; then
      # Test if ipcalc supports -c (GNU ipcalc) or -n (BSD ipcalc)
      if ipcalc -h 2>&1 | grep -q "\-c"; then
        # GNU ipcalc
        if ipcalc -c "$ip" "$subnet" &>/dev/null; then
          return 0
        else
          return 1
        fi
      elif ipcalc -h 2>&1 | grep -q "\-n"; then
        # BSD ipcalc
        local network=$(ipcalc -n "$subnet" | awk '{print $2}')
        local mask=$(ipcalc -m "$subnet" | awk '{print $2}')
        
        # Check if the IP is in the subnet
        if ipcalc "$ip" "$mask" | grep -q "Network.*$network"; then
          return 0
        else
          return 1
        fi
      fi
    fi
    
    # Try sipcalc if ipcalc failed or wasn't appropriate
    if command -v sipcalc &>/dev/null; then
      local network=$(sipcalc "$subnet" | grep "Network address" | head -1 | awk '{print $NF}')
      local broadcast=$(sipcalc "$subnet" | grep "Broadcast address" | head -1 | awk '{print $NF}')
      
      # Use sort to compare IP addresses lexicographically
      if [[ $(echo -e "$network\n$ip\n$broadcast" | sort -V | grep -n "$ip" | cut -d: -f1) -eq 2 ]]; then
        return 0
      else
        return 1
      fi
    else
      # Manual check using bash (less accurate and doesn't handle complex cases)
      local subnet_ip=${subnet%/*}
      local cidr=${subnet#*/}
      
      # Convert CIDR to netmask
      local netmask=""
      local full_octets=$((cidr / 8))
      local partial_octet=$((cidr % 8))
      
      for ((i=0; i<4; i++)); do
        if [[ $i -lt $full_octets ]]; then
          netmask+="255"
        elif [[ $i -eq $full_octets ]]; then
          netmask+="$((256 - 2**(8-partial_octet)))"
        else
          netmask+="0"
        fi
        
        [[ $i -lt 3 ]] && netmask+="."
      done
      
      # Now check using the netmask
      local IFS='.'
      read -r -a ip_array <<< "$ip"
      read -r -a subnet_array <<< "$subnet_ip"
      read -r -a netmask_array <<< "$netmask"
      
      for ((i=0; i<4; i++)); do
        if [[ $((ip_array[i] & netmask_array[i])) -ne $((subnet_array[i] & netmask_array[i])) ]]; then
          return 1
        fi
      done
      return 0
    fi
  else
    # Legacy notation with subnet prefix (e.g., 192.168.1)
    # Use simple string matching
    if [[ "$ip" == $subnet* ]]; then
      return 0
    else
      return 1
    fi
  fi
}

# Check if IP is in the expected subnet (if provided)
if [ -n "$expected_subnet" ]; then
  if is_ip_in_subnet "$new_ip" "$expected_subnet"; then
    echo "IP address is within expected subnet $expected_subnet"
  else
    echo "Error: IP address $new_ip is not in the expected subnet $expected_subnet" >&2
    
    # Release the IP before exiting with error
    if command -v dhclient &>/dev/null; then
      echo "Releasing DHCP lease before exit..."
      sudo dhclient -r "$interface" &>/dev/null || true
    elif command -v dhcpcd &>/dev/null; then
      echo "Releasing DHCP lease before exit..."
      sudo dhcpcd -k "$interface" &>/dev/null || true
    fi
    
    exit 4
  fi
fi

# Get the default gateway
gateway=$(sudo ip route | grep default | grep "$interface" | awk '{print $3}')
if [ -n "$gateway" ]; then
  echo "Default gateway: $gateway"
  
  # Test connectivity to the gateway
  echo "Testing connectivity to gateway..."
  if sudo ping -c 3 -W 2 "$gateway" &>/dev/null; then
    echo "Successfully pinged gateway"
  else
    echo "Warning: Could not ping gateway $gateway" >&2
  fi
else
  echo "Warning: No default gateway found" >&2
fi

# Get the DNS servers from /etc/resolv.conf
echo "DNS servers:"
sudo cat /etc/resolv.conf | grep nameserver | awk '{print $2}'

# Test internet connectivity
echo "Testing internet connectivity..."
if sudo ping -c 3 -W 5 8.8.8.8 &>/dev/null; then
  echo "Internet connectivity: OK"
else
  echo "Warning: No internet connectivity" >&2
fi

# Test DNS resolution
echo "Testing DNS resolution..."
if sudo host google.com &>/dev/null; then
  echo "DNS resolution: OK"
else
  echo "Warning: DNS resolution failed" >&2
fi

# Report success
echo "DHCP test completed successfully"

# Release the IP address at the end of the test
echo "Releasing DHCP lease at end of test..."
if command -v dhclient &>/dev/null; then
  sudo dhclient -r "$interface" &>/dev/null
elif command -v dhcpcd &>/dev/null; then
  sudo dhcpcd -k "$interface" &>/dev/null
fi

# Optionally restore the initial state if there was an initial IP
if [ -n "$initial_ip" ]; then
  echo "Requesting restoration of original IP configuration..."
  if command -v dhclient &>/dev/null; then
    sudo dhclient "$interface" &>/dev/null
  elif command -v dhcpcd &>/dev/null; then
    sudo dhcpcd "$interface" &>/dev/null
  fi
fi

exit 0 