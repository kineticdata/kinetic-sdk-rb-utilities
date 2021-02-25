require "kinetic_sdk"
require "fileutils"
require "json"
require "yaml"
require "logger"
require "csv"

# determine the present working directory
PWD = File.expand_path(File.dirname(__FILE__))

# setup logging
LOGGER = Logger.new("#{PWD}/output.log")
LOGGER.level = Logger::INFO

# Get the config file
config_file = "#{PWD}/config.yaml"
env = nil
begin
  env = YAML.load(ERB.new(open(config_file).read).result(binding))
rescue
  LOGGER.error "There was a problem loading the configuration file"
  exit
end

# load config from config file
SPACE_URL       = env['SPACE_URL']
SPACE_SLUG      = env['SPACE_SLUG']
SPACE_USERNAME  = env['SPACE_USERNAME']
SPACE_PASSWORD  = env['SPACE_PASSWORD']
LOG_LEVEL       = env['LOG_LEVEL']
TEAM_TO_REMOVE_USER_FROM = env['TEAM_TO_REMOVE_USER_FROM']

# create space connection
CORE_SPACE = KineticSdk::Core.new({
  space_server_url: SPACE_URL,
  space_slug: SPACE_SLUG,
  username: SPACE_USERNAME,
  password: SPACE_PASSWORD,
  options: {
      log_level: LOG_LEVEL,
      max_redirects: 3
  }
})

# method to remove memberships for list of users
def remove_memberships(users)
  # loop over users
  users.each do |user|
    username = user["username"]
    is_member = user['memberships'].any? { |m| m["team"]["name"] == TEAM_TO_REMOVE_USER_FROM}
    
    # If user is member of team, remove them from the team
    if is_member
      LOGGER.info "Removing  #{username} from #{TEAM_TO_REMOVE_USER_FROM}."
      response = CORE_SPACE.remove_team_membership(TEAM_TO_REMOVE_USER_FROM, username)
    end
  end
end

# configure parameters for call to fetch users
params = {"limit" => "1000", "include" => "memberships"}
# make initial call
response = CORE_SPACE.find_users(params)
# Remove memberships from initial set of users
remove_memberships(response.content['users']  || [])

# if a next page token exists, keep retrieving users and add them to the results
while (!response.content["nextPageToken"].nil?)
  LOGGER.info "Fetching Next Page"
  params['pageToken'] = response.content["nextPageToken"]
  response = CORE_SPACE.find_users(params)
  
  # remove_memberships
  remove_memberships(response.content["users"] || [])
end
