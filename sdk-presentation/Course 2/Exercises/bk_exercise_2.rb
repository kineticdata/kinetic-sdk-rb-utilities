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

response = conn.find_form(config["KAPP"],"does-not-exist")