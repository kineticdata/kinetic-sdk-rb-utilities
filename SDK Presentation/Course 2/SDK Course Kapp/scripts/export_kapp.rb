require "kinetic_sdk"
include KineticSdk::Utils::KineticExportUtils

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
  "include"=>config["INCLUDE"],

}

# puts conn.pretty_inspect
response = conn.export_kapp("sdk-course").content
kapp_slug = response['kapp']['slug']

# Prepare the output shape.
export_shape = prepare_shape(
    "{slug}.categories",    
    "{slug}.forms.{slug}",
    "{slug}.categoryAttributeDefinitions",
    "{slug}.formAttributeDefinitions",
    "{slug}.formTypes",
    "{slug}.kappAttributeDefinitions",
    "{slug}.securityPolicyDefinitions",
    "{slug}.webhooks.{name}",
    "{slug}.webApis.{slug}",
  )
  
  # Create a new shape for the kapp using the kapp slug as the key.
  data = {}
  data[kapp_slug] = response['kapp']
 
  # Process the export, sending data to directories and files
  process_export("#{PWD}/core/space/kapps", export_shape, data)

