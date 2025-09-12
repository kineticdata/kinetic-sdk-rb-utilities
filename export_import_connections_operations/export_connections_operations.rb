require 'kinetic_sdk'
require 'optparse'
require 'logger'
require 'json'
require 'yaml'
require 'fileutils'

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
  opts.banner = "Usage: export_connections_operations.rb [options]"

  opts.on("-c", "--config CONFIG_FILE", "The Configuration file to use") do |config|
    options["CONFIG_FILE"] = config
  end
  
  opts.on("-o", "--output OUTPUT_DIR", "Output directory for exported files (default: exports)") do |output|
    options["OUTPUT_DIR"] = output
  end
  
  opts.on("-v", "--verbose", "Enable verbose logging") do
    logger.level = Logger::DEBUG
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

# Set default output directory
options["OUTPUT_DIR"] ||= "exports"

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

# Set http_options based on values provided in the config file.
http_options = (vars["http_options"] || {}).each_with_object({}) do |(k,v),result|
  result[k.to_sym] = v
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

# Create output directory
output_dir = options["OUTPUT_DIR"]
begin
  FileUtils.mkdir_p(output_dir)
  logger.info "Created output directory: #{output_dir}"
rescue => error
  logger.error "Failed to create output directory: #{error.message}"
  exit 1
end

# Generate timestamp for filenames
timestamp = Time.now.strftime("%Y%m%d_%H%M%S")

logger.info "Starting export of connections and operations..."

# Export Connections
logger.info "Fetching connections..."
connections_response = integrator.find_connections()

if connections_response.status == 200
  connections = connections_response.content|| []
  logger.info "Found #{connections.length} connections"
  
  # Create detailed connections export with operations
  connections_with_operations = []
  
  connections.each do |connection|
    connection_id = connection['id']
    connection_name = connection['name']
    
    logger.info "Processing connection: #{connection_name} (#{connection_id})"
    
    # Get operations for this connection
    operations_response = integrator.find_operations(connection_id)
    
    if operations_response.status == 200
      operations = operations_response.content || []
      logger.info "  Found #{operations.length} operations for connection #{connection_name}"
      
      # Add operations to connection object
      connection_with_ops = connection.dup
      connection_with_ops['operations'] = operations
      connections_with_operations << connection_with_ops
    else
      logger.warn "Failed to fetch operations for connection #{connection_name}: #{operations_response.status}"
      logger.warn "Error: #{operations_response.content['error'] || operations_response.message}" if operations_response.content
      # Still include the connection without operations
      connection_with_ops = connection.dup
      connection_with_ops['operations'] = []
      connections_with_operations << connection_with_ops
    end
  end
  
  # Write connections with operations to file
  connections_file = File.join(output_dir, "connections_with_operations_#{timestamp}.json")
  File.write(connections_file, JSON.pretty_generate(connections_with_operations))
  logger.info "Exported connections with operations to: #{connections_file}"
  
  # Also create separate files for easier processing
  connections_only_file = File.join(output_dir, "connections_#{timestamp}.json")
  File.write(connections_only_file, JSON.pretty_generate(connections))
  logger.info "Exported connections only to: #{connections_only_file}"
  
  # Extract all operations into a single file
  all_operations = []
  connections_with_operations.each do |conn|
    conn['operations'].each do |op|
      # Add connection info to operation for easier import
      op_with_conn = op.dup
      op_with_conn['connectionId'] = conn['id']
      op_with_conn['connectionName'] = conn['name']
      all_operations << op_with_conn
    end
  end
  
  operations_file = File.join(output_dir, "operations_#{timestamp}.json")
  File.write(operations_file, JSON.pretty_generate(all_operations))
  logger.info "Exported all operations to: #{operations_file}"
  
  # Create summary report
  summary = {
    "export_timestamp" => timestamp,
    "total_connections" => connections.length,
    "total_operations" => all_operations.length,
    "connections_summary" => connections.map do |conn|
      ops_count = connections_with_operations.find { |c| c['id'] == conn['id'] }&.dig('operations')&.length || 0
      {
        "id" => conn['id'],
        "name" => conn['name'],
        "type" => conn['type'],
        "operations_count" => ops_count
      }
    end
  }
  
  summary_file = File.join(output_dir, "export_summary_#{timestamp}.json")
  File.write(summary_file, JSON.pretty_generate(summary))
  logger.info "Created export summary: #{summary_file}"
  
else
  logger.error "Failed to fetch connections: #{connections_response.status}"
  logger.error "Error: #{connections_response.content['error'] || connections_response.message}" if connections_response.content
  exit 1
end

logger.info "Export completed successfully!"
logger.info "Files created in directory: #{output_dir}"
logger.info "- connections_with_operations_#{timestamp}.json (complete export)"
logger.info "- connections_#{timestamp}.json (connections only)"
logger.info "- operations_#{timestamp}.json (operations only)"
logger.info "- export_summary_#{timestamp}.json (summary report)"
