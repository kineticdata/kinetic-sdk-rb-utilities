require "kinetic_sdk"
require "teelogger"
require "CSV"

# find the directory of this script
PWD = File.expand_path(File.dirname(__FILE__))


# load the connection configuration file
begin
  config = YAML.load_file( File.join(PWD, "config.yaml") )
rescue
  raise StandardError.new "There was a problem loading the config.yaml file"
end


# setup logging
@logger = TeeLogger::TeeLogger.new(STDOUT, "#{PWD}/output.log")
@logger.level = config["LOG_LEVEL"].to_s.downcase == "debug" ? Logger::DEBUG : Logger::INFO


# Create space connection
conn = KineticSdk::Core.new({
  app_server_url: config["SYSTEM_URL"],
  username: config["SYSTEM_USERNAME"],
  password: config["SYSTEM_PASSWORD"],
  options: { log_level: config["LOG_LEVEL"] }
})

# fetch all spaces from the System API
spaces = conn.find_spaces().content['spaces']

# iterate over each space and search to see if the user exists
spaces.each do |space|
  spaceAdmins = conn.find_users_in_system(space["slug"], {"q" => "spaceAdmin = \"true\"", "limit" => 1000}).content['users']
  # filter only kinetic employees
  space["kineticDataAdmins"] = spaceAdmins.filter { |u| u["email"] && u["email"].include?("kinetic") }.map { |u| u["displayName"] }.join(", ")
end

# Write output.csv file
CSV.open(File.join(PWD, "output.csv"), "wb") do |csv|
  csv << spaces.first.keys # adds the attributes name on the first line
  spaces.each do |hash|
    csv << hash.values
  end
end