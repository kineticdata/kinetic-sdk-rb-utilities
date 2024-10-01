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
http_conn = KineticSdk::CustomHttp.new({})

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

params = {
  "nat" => "US",
  "results" => 100
}
 
#   # statements to be executed
  response =  http_conn.get("https://randomuser.me/api/", params).content['results']
  
  response.each do |user|
    new_user = {}
    new_user["username"] = "#{user["name"]["first"]}#{user["name"]["last"]}"
    new_user["displayName"] = "#{user["name"]["first"]}#{user["name"]["last"]}"
    new_user["enabled"] = true
    new_user["spaceAdmin"] = false
    new_user["space_slug"] = config["SPACE_SLUG"]

    conn.add_user( new_user )
  end 






