require 'kinetic_sdk'
require 'optparse'
require 'logger'
require 'json'
require 'yaml'

logger = Logger.new(STDERR)
logger.level = Logger::INFO
logger.formatter = proc do |severity, datetime, progname, msg|
  date_format = datetime.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
  "[#{date_format}] #{severity}: #{msg}\n"
end

# Determine the Present Working Directory
pwd = File.expand_path(File.dirname(__FILE__))

ARGV << '-h' if ARGV.empty?

# The options specified on the command line will be collected in *options*.
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: import_connections_operations.rb [options]"

  opts.on("-c", "--config CONFIG_FILE", "The Configuration file to use") do |config|
    options["CONFIG_FILE"] = config
  end
  
  opts.on("-f", "--file IMPORT_FILE", "JSON file to import (connections_with_operations, connections, or operations)") do |file|
    options["IMPORT_FILE"] = file
  end
  
  opts.on("-t", "--type IMPORT_TYPE", "Import type: 'connections', 'operations', or 'both' (default: both)") do |type|
    options["IMPORT_TYPE"] = type
  end
  
  opts.on("-v", "--verbose", "Enable verbose logging") do
    logger.level = Logger::DEBUG
  end
  
  opts.on("--dry-run", "Show what would be imported without making changes") do
    options["DRY_RUN"] = true
  end
  
  opts.on("--skip-existing", "Skip items that already exist instead of updating them") do
    options["SKIP_EXISTING"] = true
  end
  
  # No argument, shows at tail.  This will print an options summary.
  # Try it and see!
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

# Validate required options
if options["CONFIG_FILE"].nil?
  logger.error "Configuration file is required. Use -c option."
  exit 1
end

if options["IMPORT_FILE"].nil?
  logger.error "Import file is required. Use -f option."
  exit 1
end

# Set defaults
options["IMPORT_TYPE"] ||= "both"

# determine the directory paths
platform_template_path = File.dirname(File.expand_path(__FILE__))

vars = {}
file = "#{platform_template_path}/#{options['CONFIG_FILE']}"

# Check if configuration file exists
logger.info "Validating configuration file."
begin
  if File.exist?(file) != true
    raise "The file \"#{options['CONFIG_FILE']}\" does not exist."
  end
rescue => error
  logger.error error
  exit 1
end

# Read the config file specified in the command line into the variable "vars"
begin
  vars.merge!(YAML.load(File.read(file)))
rescue => error
  logger.error "Error loading YAML configuration"
  logger.error error
  exit 1
end
logger.info "Configuration file passed validation."

# Check if import file exists
unless File.exist?(options["IMPORT_FILE"])
  logger.error "Import file does not exist: #{options['IMPORT_FILE']}"
  exit 1
end

# Read import file
begin
  import_data = JSON.parse(File.read(options["IMPORT_FILE"]))
rescue => error
  logger.error "Error reading import file: #{error.message}"
  exit 1
end

# Initialize the Integrator SDK
begin
  integrator = KineticSdk::Integrator.new({
    space_server_url: vars["core"]["server_url"],
    space_slug: vars["core"]["space_slug"],
    username: vars["core"]["service_user_username"],
    password: vars["core"]["service_user_password"],
    options: {
            oauth_client_id: vars["options"]['oauth_client_id'],
            oauth_client_secret: vars["options"]['oauth_client_secret'],
            log_level: "info",
            log_output: "stdout",
            max_redirects: 0
          }
  })
rescue => error
  logger.error "Failed to initialize Integrator SDK: #{error.message}"
  exit 1
end

# Function to process each connection
def process_connection(integrator, connection_data, dry_run = false, skip_existing = false, logger = nil)
  connection_id = connection_data["id"]
  connection_name = connection_data["name"]
  
  # clientSecret and password should be empty for import
  connection_data["config"]["auth"]["clientSecret"] = "" if connection_data["config"]["auth"].key?("clientSecret")
  connection_data["config"]["auth"]["password"] = "" if connection_data["config"]["auth"].key?("password")

  logger.info "Processing connection: #{connection_name} (#{connection_id})"
  
  if dry_run
    logger.info "  [DRY RUN] Would process connection: #{connection_name}"
    return { status: "dry_run", action: "would_process" }
  end

  # Check if connection exists
  response = integrator.find_connection(connection_id)

  if response.status == 200 && response.content['id']
    if skip_existing
      logger.info "  Connection #{connection_name} exists, skipping..."
      return { status: "skipped", action: "exists" }
    else
      logger.info "  Connection #{connection_name} exists, updating..."
      # Remove operations from connection data for update (they're handled separately)
      update_data = connection_data.dup
      update_data.delete('operations')

      update_response = integrator.update_connection(connection_id, update_data)
      
      if update_response.status == 200
        logger.info "  Successfully updated connection: #{connection_name}"
        return { status: "success", action: "updated" }
      else
        logger.error "  Failed to update connection: #{connection_name}"
        logger.error "  Error: #{update_response.content['error'] || update_response.message}"
        return { status: "error", action: "update_failed", error: update_response.content }
      end
    end
  else
    logger.info "  Connection #{connection_name} doesn't exist, creating new..."
    # Remove operations from connection data for creation (they're handled separately)
    create_data = connection_data.dup
    create_data.delete('operations')
    
    create_response = integrator.add_connection(create_data)
    
puts JSON.pretty_generate( create_data)
    if create_response.status == 201
      logger.info "  Successfully created connection: #{connection_name}"
      return { status: "success", action: "created" }
    else
      logger.error "  Failed to create connection: #{connection_name}"
      logger.error "  Error: #{create_response.content['error'] || create_response.message}"
      logger.error "  Error: #{create_response.content['validationErrors']}"
      return { status: "error", action: "create_failed", error: create_response.content }
    end
  end
end

# Function to process each operation
def process_operation(integrator, operation_data, dry_run = false, skip_existing = false, logger = nil)
  connection_id = operation_data["connectionId"]
  operation_id = operation_data["id"]
  operation_name = operation_data["name"] || "Unnamed Operation"
  
  logger.info "Processing operation: #{operation_name} (#{operation_id}) for connection #{connection_id}"
  
  if dry_run
    logger.info "  [DRY RUN] Would process operation: #{operation_name}"
    return { status: "dry_run", action: "would_process" }
  end

  # Check if operation exists
  response = integrator.find_operation(connection_id, operation_id)

  if response.status == 200 && response.content['id']
    if skip_existing
      logger.info "  Operation #{operation_name} exists, skipping..."
      return { status: "skipped", action: "exists" }
    else
      logger.info "  Operation #{operation_name} exists, updating..."
      # Remove connection metadata from operation data
      update_data = operation_data.dup
      update_data.delete('connectionId')
      update_data.delete('connectionName')
      
      update_response = integrator.update_operation(connection_id, operation_id, update_data)
      
      if update_response.status == 200
        logger.info "  Successfully updated operation: #{operation_name}"
        return { status: "success", action: "updated" }
      else
        logger.error "  Failed to update operation: #{operation_name}"
        logger.error "  Error: #{update_response.content['error'] || update_response.message}"
        return { status: "error", action: "update_failed", error: update_response.content }
      end
    end
  else
    logger.info "  Operation #{operation_name} doesn't exist, creating new..."
    # Remove connection metadata from operation data
    create_data = operation_data.dup
    create_data.delete('connectionId')
    create_data.delete('connectionName')
    
    create_response = integrator.add_operation(connection_id, create_data)
    
    if create_response.status == 201
      logger.info "  Successfully created operation: #{operation_name}"
      return { status: "success", action: "created" }
    else
      logger.error "  Failed to create operation: #{operation_name}"
      logger.error "  Error: #{create_response.content['error'] || create_response.message}"
      return { status: "error", action: "create_failed", error: create_response.content }
    end
  end
end

# Initialize counters
connection_stats = { processed: 0, created: 0, updated: 0, skipped: 0, errors: 0 }
operation_stats = { processed: 0, created: 0, updated: 0, skipped: 0, errors: 0 }

logger.info "Starting import process..."
logger.info "Import type: #{options['IMPORT_TYPE']}"
logger.info "Dry run mode: #{options['DRY_RUN'] ? 'Yes' : 'No'}"
logger.info "Skip existing: #{options['SKIP_EXISTING'] ? 'Yes' : 'No'}"

# Determine the structure of the import data
if import_data.is_a?(Array)
  # Check if it's an array of connections with operations, or just operations
  if import_data.first && import_data.first.key?('operations')
    # Array of connections with operations
    connections_data = import_data
    operations_data = []
    
    # Extract operations if needed
    if options["IMPORT_TYPE"] == "operations" || options["IMPORT_TYPE"] == "both"
      connections_data.each do |conn|
        if conn['operations']
          conn['operations'].each do |op|
            op_with_conn = op.dup
            op_with_conn['connectionId'] = conn['id']
            op_with_conn['connectionName'] = conn['name']
            operations_data << op_with_conn
          end
        end
      end
    end
  elsif import_data.first && import_data.first.key?('connectionId')
    # Array of operations
    connections_data = []
    operations_data = import_data
  else
    # Array of connections only
    connections_data = import_data
    operations_data = []
  end
else
  logger.error "Import data must be an array"
  exit 1
end

# Process connections if requested
if (options["IMPORT_TYPE"] == "connections" || options["IMPORT_TYPE"] == "both") && !connections_data.empty?
  logger.info "Processing #{connections_data.length} connections..."
  
  connections_data.each do |connection|
    result = process_connection(integrator, connection, options["DRY_RUN"], options["SKIP_EXISTING"], logger)
    
    connection_stats[:processed] += 1
    case result[:action]
    when "created", "would_process"
      connection_stats[:created] += 1
    when "updated"
      connection_stats[:updated] += 1
    when "exists"
      connection_stats[:skipped] += 1
    when "create_failed", "update_failed"
      connection_stats[:errors] += 1
    end
  end
end

# Process operations if requested
if (options["IMPORT_TYPE"] == "operations" || options["IMPORT_TYPE"] == "both") && !operations_data.empty?
  logger.info "Processing #{operations_data.length} operations..."
  
  operations_data.each do |operation|
    result = process_operation(integrator, operation, options["DRY_RUN"], options["SKIP_EXISTING"], logger)
    
    operation_stats[:processed] += 1
    case result[:action]
    when "created", "would_process"
      operation_stats[:created] += 1
    when "updated"
      operation_stats[:updated] += 1
    when "exists"
      operation_stats[:skipped] += 1
    when "create_failed", "update_failed"
      operation_stats[:errors] += 1
    end
  end
end

# Final summary
logger.info "########################"
logger.info "Import Completed."
logger.info "########################"
logger.info "Connection Summary:"
logger.info "  Processed: #{connection_stats[:processed]}"
logger.info "  Created: #{connection_stats[:created]}"
logger.info "  Updated: #{connection_stats[:updated]}"
logger.info "  Skipped: #{connection_stats[:skipped]}"
logger.info "  Errors: #{connection_stats[:errors]}"
logger.info ""
logger.info "Operation Summary:"
logger.info "  Processed: #{operation_stats[:processed]}"
logger.info "  Created: #{operation_stats[:created]}"
logger.info "  Updated: #{operation_stats[:updated]}"
logger.info "  Skipped: #{operation_stats[:skipped]}"
logger.info "  Errors: #{operation_stats[:errors]}"

# Exit with error code if there were any errors
if connection_stats[:errors] > 0 || operation_stats[:errors] > 0
  exit 1
end
