#!/bin/bash
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