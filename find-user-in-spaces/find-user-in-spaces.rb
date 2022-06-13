require "kinetic_sdk"
require "optparse"
require "teelogger"


options = {}
OptionParser.new do |opts|
  opts.on("--user [User]", "User") do |v|
    options[:user] = v
  end
  opts.on("--remove [Remove User]", "Remove") do |v|
    options[:remove] = v
  end
end.parse!

raise "A user must be specified with the --user [User] option" if options[:user].nil?
user = options[:user]
remove = options[:remove] && options[:remove].downcase == "true" ? true : false

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
@logger.info("Running in REMOVE mode") if remove


# Create space connection
conn = KineticSdk::Core.new({
  app_server_url: config["SYSTEM_URL"],
  username: config["SYSTEM_USERNAME"],
  password: config["SYSTEM_PASSWORD"],
  options: { log_level: config["LOG_LEVEL"] }
})

# keep track of found spaces
found_spaces = []

# fetch all spaces from the System API
spaces = conn.find_spaces().content['spaces']

# iterate over each space and search to see if the user exists
spaces.each do |space|
  users = conn.find_users_in_system(space["slug"], {"q" => "username =* \"#{user}\" OR displayName =* \"#{user}\" OR email =* \"#{user}\""}).content['users']
  if users.size > 0 
    found_spaces.push(space)
    if remove
      @logger.info("Removing user found in #{space["slug"]}")
      users.each do |user|
        user_with_space_slug = user
        user_with_space_slug["space_slug"] = space["slug"]
        conn.delete_user(user_with_space_slug)
      end
    end
  end
end

# Log Statistics
if found_spaces.size > 0
  @logger.info("User #{user} #{remove ? " removed" : " found"} in #{found_spaces.size}")
  found_spaces.each { |space| @logger.info("  \"#{space["name"]} - #{space["slug"]}\"") }

  @logger.info("Here's a little more usable format :) ")
  @logger.info(found_spaces.map { |s| s["slug"] } )
end
