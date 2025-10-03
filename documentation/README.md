# Backup Validator Documentation

This directory contains detailed documentation for the scripts and configurations used in the Backup Validator tool.

## Scripts

- [DNS Test](dns_test.md) - Tests if a hostname resolves to the expected IP address
- [DHCP Test](dhcp_test.md) - Tests if DHCP is working properly on a specified network interface
- [Kerberos Test](kerberos_test.md) - Verifies if provided credentials can be used to obtain a valid Kerberos ticket
- [LDAPS Test](ldaps_test.md) - Checks connectivity to a domain controller or LDAP server over SSL
- [MSSQL Test](mssql_test.md) - Executes a SQL query via Kerberos-authenticated sqlcmd and compares the result

## Configurations

- [Sudo Configuration](sudo_configuration.md) - Details about the sudo privileges required for certain scripts

## Additional Resources

For general usage and setup of the Backup Validator tool, please refer to the [main README](../README.md) file in the root directory. 