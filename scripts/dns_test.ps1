# DNS Test Script - Tests if a hostname resolves to the expected IP address

param (
    [Parameter(Mandatory=$false)]
    [string]$hostname,
    
    [Parameter(Mandatory=$false)]
    [string]$expectedIp,
    
    [Parameter(Mandatory=$false)]
    [string]$dnsServer
)

# Parse named parameters if provided in the format --name=value
$args | ForEach-Object {
    if ($_ -match '^--hostname=(.+)$') {
        $hostname = $matches[1]
    }
    elseif ($_ -match '^--expected-ip=(.+)$') {
        $expectedIp = $matches[1]
    }
    elseif ($_ -match '^--dns-server=(.+)$') {
        $dnsServer = $matches[1]
    }
}

# Check required parameters
if ([string]::IsNullOrEmpty($hostname)) {
    Write-Error "Error: Hostname is required"
    exit 1
}

if ([string]::IsNullOrEmpty($expectedIp)) {
    Write-Error "Error: Expected IP address is required"
    exit 1
}

Write-Host "Testing DNS resolution for $hostname (expected: $expectedIp)"

try {
    $resolvedIp = $null
    
    # Perform DNS lookup
    if ([string]::IsNullOrEmpty($dnsServer)) {
        # Use default DNS server
        $dnsResults = Resolve-DnsName -Name $hostname -Type A -ErrorAction Stop | Where-Object { $_.Type -eq 'A' }
    }
    else {
        # Use specified DNS server
        $dnsResults = Resolve-DnsName -Name $hostname -Type A -Server $dnsServer -ErrorAction Stop | Where-Object { $_.Type -eq 'A' }
    }
    
    # Get the first A record
    if ($dnsResults -and $dnsResults.Count -gt 0) {
        if ($dnsResults.GetType().IsArray) {
            $resolvedIp = $dnsResults[0].IPAddress
        }
        else {
            $resolvedIp = $dnsResults.IPAddress
        }
    }
    
    # If Resolve-DnsName fails, try using .NET directly
    if ([string]::IsNullOrEmpty($resolvedIp)) {
        $ips = [System.Net.Dns]::GetHostAddresses($hostname) | Where-Object { $_.AddressFamily -eq 'InterNetwork' }
        if ($ips -and $ips.Count -gt 0) {
            $resolvedIp = $ips[0].IPAddressToString
        }
    }
    
    # Check if resolution was successful
    if ([string]::IsNullOrEmpty($resolvedIp)) {
        Write-Error "Error: Could not resolve $hostname"
        exit 2
    }
    
    Write-Host "Resolved IP: $resolvedIp"
    
    # Compare with expected IP
    if ($resolvedIp -eq $expectedIp) {
        Write-Host "Success: $hostname resolved to expected IP $expectedIp"
        exit 0
    }
    else {
        Write-Error "Error: $hostname resolved to $resolvedIp (expected: $expectedIp)"
        exit 3
    }
}
catch {
    Write-Error "Error: $_"
    exit 2
} 