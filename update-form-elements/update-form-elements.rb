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
}.compact

parameters["export"] = true 
parameters["elementsToUpdate"] = config["ELEMENTS_TO_UPDATE"] if config["ELEMENTS_TO_UPDATE"]

def recursive_element_find(obj, target, update)
  case obj
  when Array
    obj.each do |e|
      case e
      when Array, Hash
        recursive_element_find(e, target, update)
      end
    end
  when Hash
    # If Element is found by name update the properties.
    if obj && obj.has_key?('name') && target.include?(obj["name"])
      @updated = true
      @logger.info "\t Updating \"#{obj['name']}\" element"
      obj.merge!(update) 
    end  
    obj.each do |k,v|
      case v
      when Array, Hash
        recursive_element_find(v, target, update)
      end
    end
  end
end

# Get Submissions
if !config["FORM_SLUG"].nil?
	response =  conn.find_form(config["KAPP_SLUG"], config["FORM_SLUG"], parameters) # Find the Form
  response.content['forms'] = [response.content['form']] # Convert to array to be consistent with results contianing multiple forms
  response.content.delete('form') # Delete the form object, it is no longer needed
else
	response =  conn.find_forms(config["KAPP_SLUG"], parameters) # Find the Forms
end

# Process the updates
response.content['forms'].each{ |form|
  @logger.info("Checking: #{form['slug']}")
  # Get the full form in "Export" format
  properties = conn.find_form(config["KAPP_SLUG"], form['slug'], parameters).content['form']
  @updated = false 
  # Delete elements from the form object
  properties['pages'] = recursive_element_find(properties['pages'], parameters["elementsToUpdate"], config["UPDATE"])
  # Update the form with the new properties
  if @updated
    @logger.info "\t Updating the form: #{properties['name']}"
    response = conn.update_form(config['KAPP_SLUG'], properties['slug'], properties)
    @logger.info "\t Http Response Code: #{response.code}"
  end
}

puts "Finished"





