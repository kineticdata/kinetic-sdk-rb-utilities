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
parameters["elementsToDelete"] = config["ELEMENTS_TO_DELETE"] if config["ELEMENTS_TO_DELETE"]


@logger.info "Starting Element Deletion"
@logger.info "Deleting: #{parameters["elementsToDelete"]}"

def recursive_element_delete(obj, target)
  case obj
  when Array
    obj.delete_if {|e| 
      exists = target.include?(e["name"])
      @logger.info "\t Deleting: #{e["name"]}" if exists
      exists
    }
    obj.each do |e|
      case e
      when Array, Hash
        recursive_element_delete(e, target)
      end
    end
  when Hash
    obj.each do |k,v|
      case v
      when Array, Hash
        recursive_element_delete(v, target)
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
	response =  conn.find_forms(config["KAPP_SLUG"]) # Find the Forms
end

# Process the updates
response.content['forms'].each{ |form|
  @logger.info("Checking: #{form['slug']}")

  # Get the full form in "Export" format
  properties = conn.find_form(config["KAPP_SLUG"], form['slug'], parameters).content['form']
  # Delete elements from the form object
  properties = recursive_element_delete(properties, parameters["elementsToDelete"])
  # Update the form with the new properties
  @logger.info "\t Updating the form: #{properties['name']}"
  response = conn.update_form(config['KAPP_SLUG'], properties['slug'], properties)
  @logger.info "\t Http Response Code: #{response.code}"
}

puts "Finished"





