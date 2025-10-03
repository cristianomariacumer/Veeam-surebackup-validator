# MSSQL Test

The MSSQL test script executes a SQL query against a Microsoft SQL Server instance using Kerberos (keytab) authentication and validates the returned result.

## Requirements

- Kerberos client utilities (`kinit`, `klist`) installed on the host
- A readable keytab file containing the service principal used to authenticate
- Microsoft `sqlcmd` CLI available in `PATH` (usually from the `mssql-tools` package and Microsoft ODBC driver)
- Network connectivity to the target SQL Server host and port

## Usage

```
GET /backup-validator/mssql_test?keytab=/etc/security/sqlsvc.keytab&host=db.example.com&query=SELECT%201&expected=1
```

Common parameters:

- `keytab` (required): Path to the keytab file used for Kerberos authentication
- `principal` (optional): Fully qualified Kerberos principal; detected from the keytab if omitted
- `host` (required): SQL Server hostname or IP address
- `port` (optional): TCP port (default `1433`)
- `database` (optional): Database to connect to before running the query
- `query` (required): SQL statement to execute
- `expected` (required): Expected textual result; whitespace and carriage returns are trimmed before comparison

Sensitive parameters (`keytab` path, `principal`) should be passed via POST JSON to avoid leaking into logs:

```
POST /backup-validator/mssql_test
Content-Type: application/json

{
  "keytab": "/etc/security/sqlsvc.keytab",
  "principal": "sqlsvc/db.example.com@EXAMPLE.COM",
  "host": "db.example.com",
  "database": "Inventory",
  "query": "SELECT COUNT(*) FROM Products",
  "expected": "42"
}
```

## Response Examples

Success:
```json
{
  "status": "success",
  "message": "Using principal sqlsvc/db.example.com@EXAMPLE.COM to authenticate against db.example.com:1433\nExecuting query: SELECT COUNT(*) FROM Products\nQuery result: 42\nSuccess: Query result matches expected output"
}
```

Failure (mismatched result):
```json
{
  "status": "error",
  "message": "Using principal sqlsvc/db.example.com@EXAMPLE.COM to authenticate against db.example.com:1433\nExecuting query: SELECT COUNT(*) FROM Products\nQuery result: 41\nError: Query result '41' does not match expected '42'"
}
```

Failure (authentication issue):
```json
{
  "status": "error",
  "message": "Using principal sqlsvc/db.example.com@EXAMPLE.COM to authenticate against db.example.com:1433\nExecuting query: SELECT COUNT(*) FROM Products\nError: Failed to obtain Kerberos ticket using the provided keytab"
}
```

## Notes

- The script acquires Kerberos credentials in a temporary cache and destroys them after execution, preventing interference with existing ticket caches.
- `sqlcmd` is invoked with `-W -h -1` to suppress extra whitespace and headers, ensuring output comparison is reliable.
- Ensure the service principal in the keytab has the required permissions to run the query against the database.
