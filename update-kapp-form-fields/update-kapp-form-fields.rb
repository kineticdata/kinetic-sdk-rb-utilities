require "kinetic_sdk"
require "optparse"
require "teelogger"


options = {}
OptionParser.new do |opts|
  opts.on("--kapp [Kapp Slug]", "Kapp slug") do |v|
    options[:kapp_slug] = v
  end
end.parse!

raise "A kapp must be specified with the --kapp [kapp-slug] option" if options[:kapp_slug].nil?
kapp_slug = options[:kapp_slug]


# find the directory of this script
PWD = File.expand_path(File.dirname(__FILE__))


# load the connection configuration file
begin
  config = YAML.load_file( File.join(PWD, "config.yaml") )
rescue
  raise StandardError.new "There was a problem loading the config.yaml file"
end

# load the fields configuration file
begin
  updated_fields = YAML.load_file( File.join(PWD, "fields.yaml") )
rescue
  raise StandardError.new "There was a problem loading the fields.yaml file"
end


# setup logging
@logger = TeeLogger::TeeLogger.new(STDOUT, "#{PWD}/output.log")
@logger.level = config["LOG_LEVEL"].to_s.downcase == "debug" ? Logger::DEBUG : Logger::INFO


# initalize the totals
@updated, @skipped, @failed = [], [], []


# Check the specified element to see if it matches the field to update.
# Recurses if the element is a page or section element.
def process_element(element, field_name, field_properties)
  # flag to indicate an update was made
  is_updated = false
  # check if this element is a container for sub-elements (page, section)
  if element.has_key?("elements")
    element["elements"].each do |child_element|
      child_element, is_updated = process_element(child_element, field_name, field_properties)
      break if is_updated
    end
  elsif element["name"] == field_name
    field_properties.each do |property_name, property_value|
      # update the property if it currently doesn't match the desired value
      if element[property_name] != property_value
        element[property_name] = property_value
        is_updated = true
      end
    end
  end
  # return element and whether an update was made
  return element, is_updated
end


# Retrieve a list of forms in the kapp and updates each form that 
# contains one or more of the fields that are to be updated. Continuously
# pages through all the forms in the kapp.
def process_kapp_forms(updated_fields, conn, kapp_slug, params={})
  params["include"]="pages"
  response = conn.find_forms(kapp_slug, params)

  response.content["forms"].each do |form|
    @logger.info("Processing the \"#{kapp_slug}\" form \"#{form["slug"]}\"")

    # flag to indicate the form contains at least one updated field
    update_form = false

    updated_fields.each do |field|
      field.each do |name, properties|
        form["pages"].each do |page|
          page, updated_element = process_element(page, name, properties)
          if updated_element
            update_form = true
            break
          end
        end
      end
    end

    if update_form
      begin
        # update the form
        @logger.info("Updating the \"#{kapp_slug}\" form \"#{form["slug"]}\"")
        conn.update_form(kapp_slug, form["slug"], form)
        @updated << { "slug" => form["slug"] }
      rescue StandardError => e
        @failed << { "slug" => form["slug"], "error" => e }
      end
    else
      @skipped << { "slug" => form["slug"] }
    end
  end

  # Process the next page of forms if there are more
  if !response.content["nextPageToken"].nil?
    params["pageToken"] = response.content["nextPageToken"]
    process_kapp_forms(updated_fields, conn, kapp_slug, params)
  end
end


# Start
@logger.info("Processing forms in the \"#{kapp_slug}\" kapp")

# Create space connection
conn = KineticSdk::Core.new({
  space_server_url: config["SPACE_URL"],
  space_slug: config["SPACE_SLUG"],
  username: config["SPACE_USERNAME"],
  password: config["SPACE_PASSWORD"],
  options: { log_level: config["LOG_LEVEL"] }
})

# Process the forms
process_kapp_forms(updated_fields, conn, kapp_slug, { "limit" => 100 })


# Log Statistics
if @failed.size > 0
  @logger.info("Failed to update #{@failed.size} #{@failed.size == 1 ? "form" : "forms"} in the \"#{kapp_slug}\" kapp")
  @failed.each { |form| @logger.info("  Failed \"#{form["slug"]}\", reason: #{error["error"]["message"]}") }
end

@logger.info("Updated #{@updated.size} #{@updated.size == 1 ? "form" : "forms"} in the \"#{kapp_slug}\" kapp")
@updated.each { |form| @logger.info("  Updated \"#{form["slug"]}\"") }

if @skipped.size > 0
  @logger.info("Skipped #{@skipped.size} #{@skipped.size == 1 ? "form" : "forms"} in the \"#{kapp_slug}\" kapp")
  @skipped.each { |form| @logger.info("  Skipped \"#{form["slug"]}\"") }
end
