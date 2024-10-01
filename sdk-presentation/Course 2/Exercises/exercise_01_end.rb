require "kinetic_sdk"

# Create space connection
conn = KineticSdk::Core.new({
  space_server_url: "",
  space_slug: "",
  username: "",
  password: ""
})

response = conn.me()
puts response.pretty_inspect
puts response.content.pretty_inspect

