#!/bin/bash
# LDAPS Connectivity Test Script
# Tests LDAP over SSL connectivity to a domain controller
# Exit codes:
#  0 = Success: LDAPS connection and search successful
#  1 = Error: Missing required parameters
#  2 = Error: ldapsearch command not found
#  3 = Error: LDAPS connection failed
#  4 = Error: LDAPS search failed
#  5 = Error: Authentication failed
#  6 = Error: Certificate validation failed

# Set default values
TIMEOUT=10
PORT=636
VERIFY_CERT=true
SEARCH_FILTER="(objectClass=*)"
ATTRS="dn"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --server=*)
      SERVER="${1#*=}"
      shift
      ;;
    --port=*)
      PORT="${1#*=}"
      shift
      ;;
    --base-dn=*)
      BASE_DN="${1#*=}"
      shift
      ;;
    --username=*)
      USERNAME="${1#*=}"
      shift
      ;;
    --password=*)
      PASSWORD="${1#*=}"
      shift
      ;;
    --search-filter=*)
      SEARCH_FILTER="${1#*=}"
      shift
      ;;
    --attrs=*)
      ATTRS="${1#*=}"
      shift
      ;;
    --timeout=*)
      TIMEOUT="${1#*=}"
      shift
      ;;
    --verify-cert=*)
      VERIFY_CERT="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown parameter: $1"
      shift
      ;;
  esac
done

# Check for required parameters
if [ -z "$SERVER" ] || [ -z "$BASE_DN" ]; then
  echo "Error: Required parameters missing"
  echo "Usage: ldaps_test.sh --server=ldap.example.com --base-dn=dc=example,dc=com [options]"
  echo ""
  echo "Required parameters:"
  echo "  --server=HOSTNAME    LDAP server hostname or IP address"
  echo "  --base-dn=BASE_DN    Base DN for search (e.g. dc=example,dc=com)"
  echo ""
  echo "Optional parameters:"
  echo "  --port=PORT          LDAPS port (default: 636)"
  echo "  --username=USERNAME  Bind DN for authentication"
  echo "  --password=PASSWORD  Password for authentication"
  echo "  --search-filter=FILTER  LDAP search filter (default: (objectClass=*))"
  echo "  --attrs=ATTRS        Comma-separated list of attributes to return (default: dn)"
  echo "  --timeout=SECONDS    Connection timeout in seconds (default: 10)"
  echo "  --verify-cert=BOOL   Verify SSL certificate (default: true)"
  exit 1
fi

echo "Testing LDAPS connectivity to $SERVER:$PORT"
echo "Base DN: $BASE_DN"

# Check if ldapsearch is installed
if ! command -v ldapsearch &> /dev/null; then
  echo "Error: 'ldapsearch' command not found. Please install OpenLDAP client tools."
  echo "  For Debian/Ubuntu: apt-get install ldap-utils"
  echo "  For RedHat/CentOS: yum install openldap-clients"
  exit 2
fi

# Build the ldapsearch command
LDAPSEARCH_CMD="ldapsearch -o ldif-wrap=no -H ldaps://$SERVER:$PORT -b \"$BASE_DN\" -l $TIMEOUT"

# Add authentication if provided
if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
  echo "Using authentication with username: $USERNAME"
  LDAPSEARCH_CMD="$LDAPSEARCH_CMD -D \"$USERNAME\" -w \"$PASSWORD\""
else
  echo "Using anonymous bind"
  LDAPSEARCH_CMD="$LDAPSEARCH_CMD -x"
fi

# Set certificate verification options
if [ "$VERIFY_CERT" = "false" ]; then
  echo "Warning: Certificate verification disabled"
  LDAPSEARCH_CMD="$LDAPSEARCH_CMD -o tls_reqcert=never"
else
  echo "Certificate verification enabled"
fi

# Add search filter and attributes
LDAPSEARCH_CMD="$LDAPSEARCH_CMD \"$SEARCH_FILTER\" $ATTRS"

# Test SSL/TLS connection to the server first (without search)
echo "Testing LDAPS connection..."
SSL_CHECK=$(echo | openssl s_client -connect $SERVER:$PORT -showcerts 2>&1)
if [[ $? -ne 0 ]]; then
  echo "Error: Failed to establish SSL connection to $SERVER:$PORT"
  echo "$SSL_CHECK" | grep -E "error|failure|unable" | head -3
  exit 3
fi

# Check certificate expiration
echo "Checking certificate expiration..."
CERT_DATES=$(echo | openssl s_client -connect $SERVER:$PORT 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
if [ -n "$CERT_DATES" ]; then
  echo "$CERT_DATES"
  
  # Extract not after date and current date for comparison
  NOT_AFTER=$(echo "$CERT_DATES" | grep notAfter | cut -d= -f2)
  CURRENT_DATE=$(date)
  
  echo "Current date: $CURRENT_DATE"
  
  # Convert dates to seconds since epoch for comparison
  NOT_AFTER_SEC=$(date -d "$NOT_AFTER" +%s 2>/dev/null)
  CURRENT_SEC=$(date +%s)
  
  if [ $? -eq 0 ] && [ $NOT_AFTER_SEC -lt $CURRENT_SEC ]; then
    echo "Error: Certificate has expired!"
    exit 6
  elif [ $? -eq 0 ]; then
    # Calculate days until expiration
    DAYS_REMAINING=$(( ($NOT_AFTER_SEC - $CURRENT_SEC) / 86400 ))
    echo "Certificate is valid. Days until expiration: $DAYS_REMAINING"
    
    if [ $DAYS_REMAINING -lt 30 ]; then
      echo "Warning: Certificate will expire in less than 30 days!"
    fi
  fi
else
  echo "Warning: Could not extract certificate information"
fi

# Execute the LDAP search
echo "Executing LDAP search with filter: $SEARCH_FILTER"
# Use eval to properly handle the command with quotes
RESULT=$(eval $LDAPSEARCH_CMD 2>&1)
SEARCH_STATUS=$?

# Check the search result
if [ $SEARCH_STATUS -eq 0 ]; then
  # Count entries in the result (excluding metadata lines)
  ENTRY_COUNT=$(echo "$RESULT" | grep -c "^dn:")
  echo "Successfully connected and searched the directory."
  echo "Found $ENTRY_COUNT entries."
  
  # Display a small sample of the results if entries were found
  if [ $ENTRY_COUNT -gt 0 ]; then
    echo "Sample result:"
    echo "$RESULT" | grep -A 2 "^dn:" | head -10
  fi
  
  echo "LDAPS test completed successfully."
  exit 0
else
  echo "Error: LDAP search failed with status code $SEARCH_STATUS"
  
  # Check for common error patterns
  if echo "$RESULT" | grep -i "invalid credentials" > /dev/null; then
    echo "Authentication failed. Please check username and password."
    exit 5
  elif echo "$RESULT" | grep -i "certificate" > /dev/null; then
    echo "Certificate validation failed:"
    echo "$RESULT" | grep -i "certificate" | head -3
    exit 6
  elif echo "$RESULT" | grep -i "connection" > /dev/null; then
    echo "Connection error:"
    echo "$RESULT" | grep -i "connection" | head -3
    exit 3
  else
    echo "Search failed:"
    echo "$RESULT" | head -5
    exit 4
  fi
fi 