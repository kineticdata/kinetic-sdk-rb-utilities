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
    log_level: config["LOG_LEVEL"],
  }
})

params = {
  "include"=>"details, attributesMap",
}
response = conn.find_form(config["KAPP"],"general-it-request",params)
puts response.content['form'].pretty_inspect

form = response.content['form']
owning_team = form['attributesMap']['Owning Team']
puts owning_team

# Three possible scenarios.
if owning_team.empty?
  # No Owning Team attribute found. Add Attribute
  puts "Owning Team Attribute not found, add Attribute and Default"
elsif !owning_team.include?("Default")
  # Owning Team attribute found but does not contain Default. Add Default to it.
  puts "Owning Team Attribute found without Default, adding Default"
else
  # Owning Team attribute found and contains Default. Do nothing
  puts "Owning Team Attribute found, no changes"
end
