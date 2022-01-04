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
conn = KineticSdk::CustomHttp.new({
  username: config["SPACE_USERNAME"],
  password: config["SPACE_PASSWORD"],
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


# Get Paused Triggers
response =  conn.get("#{config['SPACE_URL']}/app/components/task/app/api/v2/triggers/backlog", parameters, conn.default_headers)
if response.content['triggers'].length > 0
	puts "#{response.content['triggers'].length} backlogged triggers were found"
	puts "Would you like to delete them? (Y/N)"
	STDOUT.flush
	case (gets.downcase.chomp)
	when 'y'
	  puts "Deleting Triggers"
	  STDOUT.flush
	else
	  abort "Exiting"
	end


	response.content['triggers'].each{ |trigger| 
		conn.delete("#{config['SPACE_URL']}/app/components/task/app/api/v2/triggers/#{trigger['id']}", conn.default_headers)
	}
else
	puts "No paused triggers were found"
	STDOUT.flush
end
puts "Finished unpausing the triggers"





