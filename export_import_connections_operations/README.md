# Kinetic Integrator Connection and Operation Export/Import Scripts

This repository contains two Ruby scripts for exporting and importing Kinetic Integrator connections and operations using the kinetic_sdk gem.

## Scripts Overview

### 1. export_connections_operations.rb
Exports connections and their associated operations from a Kinetic environment to JSON files.

### 2. import_connections_operations.rb  
Imports connections and operations from JSON files into a Kinetic environment.

## Prerequisites

- Ruby (tested with Ruby 2.7+)
- kinetic_sdk gem
- Required Ruby gems: json, yaml, fileutils, optparse, logger

## Installation

1. Install the kinetic_sdk gem:
   ```bash
   gem install kinetic_sdk
   ```

2. Ensure you have the required configuration files (see Configuration section below)

## Configuration

Both scripts require a YAML configuration file with the following structure:

```yaml
core:
  server_url: "https://your-kinetic-server.com"
  space_slug: "your-space-slug"  
  service_user_username: "your-username"
  service_user_password: "your-password"

# Optional HTTP options
http_options:
  timeout: 30
  max_redirects: 3
```

## Usage

### Exporting Connections and Operations

```bash
ruby export_connections_operations.rb -c config.yaml [options]
```

#### Export Options:
- `-c, --config CONFIG_FILE` - Required: Configuration file to use
- `-o, --output OUTPUT_DIR` - Output directory (default: exports)
- `-v, --verbose` - Enable verbose logging
- `-h, --help` - Show help message

#### Export Output Files:
The export creates several JSON files with timestamp suffixes:
- `connections_with_operations_YYYYMMDD_HHMMSS.json` - Complete export with nested operations
- `connections_YYYYMMDD_HHMMSS.json` - Connections only
- `operations_YYYYMMDD_HHMMSS.json` - Operations only (with connection metadata)
- `export_summary_YYYYMMDD_HHMMSS.json` - Summary report

### Importing Connections and Operations

```bash
ruby import_connections_operations.rb -c config.yaml -f import_file.json [options]
```

#### Import Options:
- `-c, --config CONFIG_FILE` - Required: Configuration file to use
- `-f, --file IMPORT_FILE` - Required: JSON file to import
- `-t, --type IMPORT_TYPE` - Import type: 'connections', 'operations', or 'both' (default: both)
- `-v, --verbose` - Enable verbose logging
- `--dry-run` - Show what would be imported without making changes
- `--skip-existing` - Skip items that already exist instead of updating them
- `-h, --help` - Show help message

#### Import File Formats:
The import script can handle three types of JSON files:

1. **Complete Export** (`connections_with_operations_*.json`):
   ```json
   [
     {
       "id": "connection-id",
       "name": "Connection Name", 
       "type": "HTTP",
       "config": {...},
       "operations": [
         {
           "id": "operation-id",
           "name": "Operation Name",
           "type": "GET",
           "config": {...}
         }
       ]
     }
   ]
   ```

2. **Connections Only** (`connections_*.json`):
   ```json
   [
     {
       "id": "connection-id",
       "name": "Connection Name",
       "type": "HTTP", 
       "config": {...}
     }
   ]
   ```

3. **Operations Only** (`operations_*.json`):
   ```json
   [
     {
       "id": "operation-id",
       "name": "Operation Name",
       "type": "GET",
       "connectionId": "connection-id",
       "connectionName": "Connection Name",
       "config": {...}
     }
   ]
   ```

## Examples

### Export all connections and operations:
```bash
ruby export_connections_operations.rb -c production.yaml -o prod_export
```

### Import everything from a complete export:
```bash
ruby import_connections_operations.rb -c staging.yaml -f prod_export/connections_with_operations_20231215_143022.json
```

### Import only connections:
```bash
ruby import_connections_operations.rb -c staging.yaml -f prod_export/connections_20231215_143022.json -t connections
```

### Import only operations:  
```bash
ruby import_connections_operations.rb -c staging.yaml -f prod_export/operations_20231215_143022.json -t operations
```

### Dry run to see what would be imported:
```bash
ruby import_connections_operations.rb -c staging.yaml -f export.json --dry-run
```

### Skip existing items instead of updating them:
```bash
ruby import_connections_operations.rb -c staging.yaml -f export.json --skip-existing
```

## Error Handling

Both scripts include comprehensive error handling:

- **Export Script**: Continues processing even if individual connections/operations fail
- **Import Script**: Provides detailed error messages and continues processing remaining items
- Both scripts exit with non-zero codes if critical errors occur
- All operations are logged with timestamps

## Logging

- Logs are written to STDERR by default
- Use `-v/--verbose` flag for debug-level logging
- Export script shows progress for each connection and operation count
- Import script shows detailed status for each create/update operation

## Migration Workflows

### Environment Migration:
1. Export from source environment:
   ```bash
   ruby export_connections_operations.rb -c prod.yaml -o migration_export
   ```

2. Import to target environment:
   ```bash
   ruby import_connections_operations.rb -c staging.yaml -f migration_export/connections_with_operations_*.json
   ```

### Backup and Restore:
1. Regular backup:
   ```bash
   ruby export_connections_operations.rb -c config.yaml -o "backup_$(date +%Y%m%d)"
   ```

2. Restore if needed:
   ```bash
   ruby import_connections_operations.rb -c config.yaml -f backup_20231215/connections_with_operations_*.json
   ```

## Troubleshooting

### Common Issues:

1. **Connection Timeouts**: Add http_options to your config:
   ```yaml
   http_options:
     timeout: 60
   ```

2. **Authentication Errors**: Verify credentials and ensure the service user has appropriate permissions

3. **Missing Dependencies**: Install required gems:
   ```bash
   gem install kinetic_sdk json yaml
   ```

4. **Large Datasets**: Use verbose mode to monitor progress and consider breaking large imports into smaller batches

## Security Notes

- Configuration files contain sensitive credentials - keep them secure
- Consider using environment variables for passwords in production
- Exported JSON files may contain sensitive configuration data - handle appropriately

## Limitations

- Scripts assume connection IDs are preserved during import
- Large exports may consume significant memory
- No built-in support for selective import (all or nothing per file)
- Operation dependencies are not validated during import
