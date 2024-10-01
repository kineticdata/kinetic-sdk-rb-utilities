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
  }
})

# Get Teams
response = conn.find_teams()

# Puts the teams to the console
puts response.inspect


# Finished
puts "Finished"