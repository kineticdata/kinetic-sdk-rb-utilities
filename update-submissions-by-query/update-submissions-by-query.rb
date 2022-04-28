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
conn = KineticSdk::Core.new({
  space_server_url: config["SERVER_URL"],
  #app_server_url: config["SPACE_URL"],
  space_slug: config["SPACE_SLUG"],
  username: config["SPACE_USERNAME"],
  password: config["SPACE_PASSWORD"],
  options: {
    log_level: config["LOG_LEVEL"],
    log_output: "stderr"
  }
})

parameters = {
  "q" => (config["QUERY"] if !config["QUERY"].nil?),
  "direction" => "DESC",
  "limit" => config["LIMIT"],
  "include" => "values"
}.compact

# Get Submissions
response =  conn.find_form_submissions(config["KAPP_SLUG"], config["FORM_SLUG"], parameters)
logger.info JSON.pretty_generate(response.content['submissions'])


if response.content['submissions'].length > 0
	puts "#{response.content['submissions'].length} submissions were found on #{config["SPACE_URL"]}."
	puts "Would you like to update them *ALL*? (Y/N)"
	STDOUT.flush
	case (gets.downcase.chomp)
	when 'y'
	  puts "Updating Submissions"
	  STDOUT.flush
	else
	  abort "Exiting"
	end
  # Update Submissions
	response.content['submissions'].each{ |submission| 
    conn.update_submission(submission['id'], body={"values": config["VALUES"]})
	}
else
	puts "No submissions were found"
	STDOUT.flush
end
puts "Finished"





