require 'bundler/setup'
Bundler.require

# find the directory of this script
PWD = File.expand_path(File.dirname(__FILE__))

# load the connection configuration file
begin
  config = YAML.load_file( File.join(PWD, "config.yaml") )
rescue
  raise StandardError.new "There was a problem loading the config.yaml file"
end

logger = Logger.new(STDERR)
logger.level = Logger::INFO
logger.formatter = proc do |severity, datetime, progname, msg|
  date_format = datetime.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
  "[#{date_format}] #{severity}: #{msg}\n"
end

# Setup logging
@logger = TeeLogger::TeeLogger.new(STDOUT, "#{PWD}/output.log")
@logger.level = config["LOG_LEVEL"].to_s.downcase == "debug" ? Logger::DEBUG : Logger::INFO

# Create space connection
conn = KineticSdk::Task.new({
  username: config["SPACE_USERNAME"],
  password: config["SPACE_PASSWORD"],
  app_server_url: "#{config["SPACE_URL"]}/app/components/task",
  options: {
	log_level: config["LOG_LEVEL"],
	log_output: "stderr"
  }
})

parameters = {
  "direction" => "DESC",
  "start" => config["START"],
  "end" => config["END"],
  "limit" => config["LIMIT"],
  "include" => "details"
}

@logger.info("CONFIGURATION: #{config.pretty_inspect}")
@logger.info("CONFIGURATION: #{config.class}")
@logger.info("CONFIGURATION: #{config['REPLACEMENTS'].pretty_inspect}")

def update_handler_properties(handler, config, conn)
	@logger.info("Updating handler: #{handler['definitionId']}")
	
	update_data = {}
	
	# Handle properties replacements
	if handler['properties'] && config["REPLACEMENTS"]["properties"]
		properties = {}
		handler['properties'].each do |property|
			name = property["name"]
			if config["REPLACEMENTS"]["properties"].key?(name)
				properties[name] = config["REPLACEMENTS"]["properties"][name]
				@logger.debug("Replacing property '#{name}' with value: #{config["REPLACEMENTS"]["properties"][name]}")
			end
		end
		update_data["properties"] = properties if !properties.empty?
	end
	
	# Handle categories replacements
	@logger.info("#")
	if handler.key?('categories') && config["REPLACEMENTS"]["categories"]
		@logger.info(handler['categories'].pretty_inspect)
		categories = []
		
		# Iterate through the replacements instead of existing categories
		config["REPLACEMENTS"]["categories"].each do |name, value|
			categories.push({name => value})
			@logger.debug("Setting category '#{name}' with value: #{value}")
		end
		update_data["categories"] = categories if !categories.empty?
	end
	
	# Only make the update call if there's something to update
	if !update_data.empty?
		update_response = conn.update_handler(handler['definitionId'], update_data)
		@logger.info(update_response.content['message'])
	else
		@logger.info("No matching properties or categories found for handler: #{handler['definitionId']}")
	end
end

# Get all handlers - include both properties and categories
response = conn.find_handlers({include: "properties,categories,details", limit: config["OPTIONS"]["LIMIT"].to_i}).content

response['handlers'].each do |handler|
	definitionId = handler['definitionId']
	if config['SEARCH_OPTIONS']['DEFINITION_ID_STARTS_WITH'] && definitionId.start_with?(config['SEARCH_OPTIONS']['DEFINITION_ID_STARTS_WITH'])
		@logger.info("Handler starts with specified string: #{definitionId}")
		update_handler_properties(handler, config, conn)			
	elsif config['SEARCH_OPTIONS']['DEFINITION_ID_CONTAINS'] && definitionId.include?(config['SEARCH_OPTIONS']['DEFINITION_ID_CONTAINS'])	
		@logger.info("Handler contains specified string: #{definitionId}")
		update_handler_properties(handler, config, conn)			
	else
		@logger.info("Skipping handler: #{handler['definitionId']}")
	end
end

puts "Finished"