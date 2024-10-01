require "kinetic_sdk"

# find the directory of this script
PWD = File.expand_path(File.dirname(__FILE__))

# load the connection configuration file
begin
  config = YAML.load_file( File.join(PWD, "config.yaml") )
rescue
  raise StandardError.new "There was a problem loading the config.yaml file"
end

logger = Logger.new(STDERR)
logger = Logger.new File.open(File.join("#{PWD}/output.log"), 'w')
logger.level = Logger::INFO
logger.formatter = proc do |severity, datetime, progname, msg|
  date_format = datetime.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
  "[#{date_format}] #{severity}: #{msg}\n"
end

# Create space connection
conn = KineticSdk::Core.new({
  space_server_url: config["SERVER_URL"],
  space_slug: config["SPACE_SLUG"],
  username: config["SPACE_USERNAME"],
  password: config["SPACE_PASSWORD"],
  options: {
    log_level: config["LOG_LEVEL"],
  }
})

params = {
  "include"=>config["INCLUDE"],
  "q"=> config["QUERY"]
}
response = conn.find_forms(config["KAPP"], params)
puts response.content.keys
puts response.content['forms'].class

response.content['forms'].each do |form|
  logger.info form['slug']
  # Update the status of the form
  form['status'] = "Active"
  conn.update_form(config["KAPP"],form['slug'],form)
end
