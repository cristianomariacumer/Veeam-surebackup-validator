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

# Sample test script

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --message=*)
      message="${1#*=}"
      shift
      ;;
    --fail=*)
      fail="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

# Default message if not provided
if [ -z "$message" ]; then
  message="Hello from sample test script!"
fi

# Check if should fail
if [ "$fail" == "true" ]; then
  echo "Error: Script failed as requested" >&2
  exit 1
fi

# Output message and exit successfully
echo "$message"
exit 0 