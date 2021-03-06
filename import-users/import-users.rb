require "kinetic_sdk"
require "fileutils"
require "json"
require "yaml"
require "logger"
require "csv"

# determine the present working directory
PWD = File.expand_path(File.dirname(__FILE__))
DATA_DIR = "#{PWD}/data"
USER_FILE = DATA_DIR + '/users.csv'


# setup logging
logger = Logger.new("#{PWD}/output.log")
logger.level = Logger::INFO

# Get the config file
config_file = "#{PWD}/config.yaml"
env = nil
begin
  env = YAML.load(ERB.new(open(config_file).read).result(binding))
rescue
  logger.error "There was a problem loading the configuration file"
  exit
end

# load config from config file
SPACE_URL       = env['SPACE_URL']
SPACE_SLUG      = env['SPACE_SLUG']
SPACE_USERNAME  = env['SPACE_USERNAME']
SPACE_PASSWORD  = env['SPACE_PASSWORD']
LOG_LEVEL       = env['LOG_LEVEL']

# create space connection
core_space = KineticSdk::Core.new({
  space_server_url: SPACE_URL,
  space_slug: SPACE_SLUG,
  username: SPACE_USERNAME,
  password: SPACE_PASSWORD,
  options: {
      log_level: LOG_LEVEL,
      max_redirects: 3
  }
})

success_count = 0
error_count = 0

# Loop over each row of the CSV file
CSV.foreach(USER_FILE, :headers => true) do |row|
    
    # Create a map of applicable attributes
    attributesMap = {
      "Manager" => ["#{row["Manager"]}"]
    }

    profileAttributesMap = {
      "Phone Number" => ["#{row["Phone Number"]}"]
    }

    memberships = row["Teams"].split(",").map do |team|
      {"team" => {"name" => team}}
    end

    # Build up user object
    user = {
        "username"              => row["User Id"],
        "displayName"           => row["Name"],
        "email"                 => row["Email Address"],
        "attributesMap"         => attributesMap,
        "profileAttributesMap"  => profileAttributesMap,
        "spaceAdmin"            => row["Is Admin"].downcase == "true" ? true : false,
        "memberships"           => memberships
    }
        
    # Create the user
    response = core_space.add_user(user).content
    
    # Log outcome
    if response['error'] 
        logger.error "Error Creating #{row['username']}: #{response['error']}" 
        error_count += 1
    else
        logger.info "Successfully Created #{row['username']}"
        success_count += 1
    end 
end

# Log count of successes
logger.info "Successfully Imported #{success_count} Users."
if error_count > 0
  logger.info "There were errors importing #{error_count} users ."
end
