require "kinetic_sdk"
require "fileutils"
require "json"
require "yaml"


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


users = conn.find_users({"q"=>"spaceAdmin = \"false\""}).content['users'] 

users.each do |user|
  if !user['spaceAdmin']
    user_to_delete = {
      "space_slug"=>config["SPACE_SLUG"],
      "username"=>user['username']
    }
    conn.delete_user(user_to_delete)
  else
    puts "###ADMIN USER FOUND###"
    exit
  end
end


