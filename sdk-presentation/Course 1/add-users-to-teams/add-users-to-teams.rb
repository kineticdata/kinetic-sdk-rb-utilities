require "kinetic_sdk"


# find the directory of this script
PWD = File.expand_path(File.dirname(__FILE__))

# load the connection configuration file
begin
  config = YAML.load_file( File.join(PWD, "config.yaml") )
rescue
  raise StandardError.new "There was a problem loading the config.yaml file"
end

# Create space connection
conn = KineticSdk::Core.new({
  space_server_url: config["SERVER_URL"],
  space_slug: config["SPACE_SLUG"],
  username: config["SPACE_USERNAME"],
  password: config["SPACE_PASSWORD"],
  options: {
      log_level: "INFO",
      max_redirects: 3
  }
})

# Get Teams from Config
teams = config["TEAMS"]

users = conn.find_users().content['users'] 

users.each do |user|
  username = user['username'] 
  conn.add_user_attribute(username, "Organization", "IT")
  conn.add_user_attribute(username, "Site", "St. Paul")
  teams.each do |team|
    conn.add_team_membership(team, username)
  end
end


