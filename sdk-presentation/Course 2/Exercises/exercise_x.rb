require "kinetic_sdk"

# Create space connection
conn = KineticSdk::Core.new({
  space_server_url: "",
  space_slug: "",
  username: "",
  password: "",
  options: {
      log_level: "INFO",
  }
})

params = {
  "include"=>"details, attributes",
}
response = conn.find_form(config["KAPP"],"general-it-request",params)
# puts response.content.pretty_inspect

form = response.content['form']

##### Update the form Description #####
# form['description'] = "This is an updated description"

# conn.update_form(config["KAPP"],"general-it-request",form)

##### Add a form Attributes #####

# form['attributes'].push({"name" => "Owning Team", "values" => ["Default"]})

##### Update the form Attributes #####
# If an attribute already exist is cannot be added.

owning_team = form['attributes'].select{ |attribute| attribute['name'] == "Owning Team" }
puts owning_team.pretty_inspect

# Three possible scenarios.
if owning_team.empty?
  # No Owning Team attribute found. Add Attribute
  puts "Owning Team Attribute not found, add Attribute and Default"
  form['attributes'].push({"name" => "Owning Team", "values" => ["Default"]})
elsif !owning_team[0]['values'].include?("Default")
  # Owning Team attribute found but does not contain Default. Add Default to it.
  puts "Owning Team Attribute found without Default, add Default"
  owning_team[0]['values'].push("Default")
else
  # Owning Team attribute found and contains Default. Do nothing
  puts "Owning Team Attribute found, do nothing"
end

puts form.pretty_inspect

conn.update_form(config["KAPP"],"general-it-request",form)
