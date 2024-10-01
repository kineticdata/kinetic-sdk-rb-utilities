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

response = conn.find_form(config["KAPP"],"general-it-request")
puts response.content.pretty_inspect
puts response.content['form'].pretty_inspect

form = response.content['form']

##### Update the form Description #####
form['description'] = "This is an updated description"

conn.update_form(config["KAPP"],"general-it-request",form)
