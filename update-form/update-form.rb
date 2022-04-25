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
  "q" => (config["QUERY"] if config["QUERY"]),
  "direction" => "DESC",
  "limit" => config["LIMIT"],
  "include" => config["INCLUDE"]
}.compact


# Get Submissions
if !config["FORM_SLUG"].nil?
	response =  conn.find_form(config["KAPP_SLUG"], config["FORM_SLUG"], parameters)
else
	response =  conn.find_forms(config["KAPP_SLUG"], parameters)
end


if response.content['forms'] #Multiple forms found
  response.content['forms'].each{ |properties|
    logger.info properties
    #Here you can update the properties object before the next line
    conn.update_form(config['KAPP_SLUG'], properties['slug'], properties)
  }
elsif response.content['form'] #Single form found
  properties = response.content['form']
  #Here you can update the properties object before the next line
  #logger.info properties
  conn.update_form(config["KAPP_SLUG"], config["FORM_SLUG"], properties)
end


puts "Finished"





