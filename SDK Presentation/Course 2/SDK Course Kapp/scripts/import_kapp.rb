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
  "include"=>config["INCLUDE"],
}

kapp_dirs = Dir["#{PWD}/core/space/kapps/*"].select { |fn| File.directory?(fn) }
kapp_dirs.each { |file|   
  kapp_slug = file.split(File::SEPARATOR).map {|x| x=="" ? File::SEPARATOR : x}.last.gsub('.json','')
  # ------------------------------------------------------------------------------
  # Add Kapp Forms
  # ------------------------------------------------------------------------------
  if (forms = Dir["#{PWD}/core/space/kapps/#{kapp_slug}/forms/*.json"]).length > 0 
    destinationForms = (conn.find_forms(kapp_slug).content['forms'] || {}).map{ |form| form['slug']}
    forms.each { |form|
      properties = File.read(form)
      form = JSON.parse(properties)
      if destinationForms.include?(form['slug'])
        conn.update_form(kapp_slug ,form['slug'], form)
      else   
        conn.add_form(kapp_slug, form)
      end
    }
  end
}