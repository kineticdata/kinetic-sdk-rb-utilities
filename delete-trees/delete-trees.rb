require "kinetic_sdk"
require "optparse"
require "teelogger"
require 'logger'

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
  "limit" => config["LIMIT"],
}


# Get Trees
response =  conn.find_trees(parameters)
if response.content['trees'].length > 0
	puts "#{response.content['trees'].length} trees were found"
	puts "Would you like to delete them *ALL*? (Y/N)"
	STDOUT.flush
	case (gets.downcase.chomp)
	when 'y'
	  puts "Deleting Trees"
	  STDOUT.flush
	else
	  abort "Exiting"
	end

  # Delete Trees
	response.content['trees'].each{ |tree| 
    conn.delete_tree({
           "source_name" => tree['sourceName'],
           "group_name" => tree['sourceGroup'],
           "tree_name" => tree['name']
         })
	}
else
	puts "No trees were found"
	STDOUT.flush
end
puts "Finished deleting the trees"





