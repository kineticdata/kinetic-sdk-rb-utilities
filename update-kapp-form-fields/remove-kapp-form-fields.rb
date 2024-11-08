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
kapp_slug = options[:kapp_slug].split(';')


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
  updated_fields = YAML.load_file( File.join(PWD, "fields_to_delete.yaml") )
rescue
  raise StandardError.new "There was a problem loading the fields.yaml file"
end



# Checks attributes and if it contains desired phrase, it replaces with it an empty string in the main string
def process_attribute(attribute,field_string)
  update_required = false
  if attribute['name'] == 'Form Configuration' && attribute['values'][0].to_s.include?(field_string)
    #Found line, attempt to disect from string
    @logger.info("Found form Configuration with Discussions Id present, attempting to remove")
    attribute['values'][0] = attribute['values'][0].sub field_string, '' #Attempts to replace desired string in-line with exact string minus phrase
    update_required = true
  else
    @logger.info("Name: " + attribute['name'])
    @logger.info('value: ' + attribute['values'][0]) if attribute['name'] == 'Form Configuration'
  end
  return attribute, update_required
end

# Check the specified element to see if it matches the field to update.
def process_element(element, field_name)
  # flag to indicate an update was made
  needs_update = false
  # check if this element is a container for sub-elements (page, section)
  if element.has_key?("elements") && element["elements"].size > 0
    element["elements"].each do |child_element|
      child_element, needs_update, needs_delete = process_element(child_element, field_name) #Recurse and pass child in case element deletion required
      if needs_delete #If child element needs to be deleted
        element['elements'].delete(child_element)
        @logger.info("Element #{child_element['name']} removed, update required")
        return element, needs_update, false #Return and reset flag, not doing so would delete up the entire chain
      end
    end
  elsif element["type"] == "field" && element["name"] == field_name #Used to mark if element needs to be updated on the kapp
      needs_update = true
      needs_delete = true
  end
  # return element and whether an update was made
  return element, needs_update, needs_delete
end

def process_element(element, field_name, parent_element=nil) #This should be able to clean element at point of discovery instead of recursing one level up to clean
  # flag to indicate an update was made
  needs_update = false
  # check if this element is a container for sub-elements (page, section)
  if element.has_key?("elements") && element["elements"].size > 0
    element["elements"].each do |child_element|
      needs_update = process_element(child_element, field_name, element) #Recurse and pass child in case element deletion required
      end
    end
  elsif element["type"] == "field" && element["name"] == field_name #Used to mark if element needs to be updated on the kapp
      begin
        parent_element['elements'].delete(element)
        @logger.info("Element #{child_element['name']} removed, update required")
        needs_update = true
      rescue
        @logger.info("Unable to remove #{element['name']} from parent #{parent_element['name']}")
      end
       
  end
  # return element and whether an update was made
  return needs_update
end

#Iterate and clean up indexDefinitions
def process_indexDefinitions(indexdefinition, field_name)
  # flag to indicate an update was made
  needs_update = false
  needs_removal = false
  # if name is value, return to remove
  if indexdefinition['name'] == field_name 
    @logger.info("Found primary index (name is #{indexdefinition['name']}), returning to delete from list")
    needs_update = true
    needs_removal = true
  elsif indexdefinition['parts'].include?(field_name)
    @logger.info("Found reference to value in an indexDefinition in #{indexdefinition['name']}")
    indexdefinition['parts'][0] = indexdefinition['parts'][0].sub field_name, '' #Replaces reference to search phrase with empty string
    needs_update = true
  end
  # return element and whether an update was made
  return indexdefinition, needs_update, needs_removal
end






################TESTING
# def process_element(element, field_name)
#   # flag to indicate an update was made
#   is_element = false
#   # check if this element is a container for sub-elements (page, section)
#   if element.has_key?("elements") && element["elements"].size > 0
#     element["elements"].each do |child_element|
#       child_element, is_element = process_element(child_element, field_name)
#       if is_element
#         child_element = []
#         @logger.info("Found child, attempting delete")
#         @logger.info("Child: " + child_element.to_s)
#         break
#       end
#     end
#   elsif element["type"] == "field" && element["name"] == field_name
#       # TODO Remove the property

#         is_element = true
#     end
#   # return element and whether an update was made
#   return element, is_element
# end
#############

# Retrieve a list of forms in the kapp and updates each form that 
# contains one or more of the fields that are to be updated. Continuously
# pages through all the forms in the kapp.
def process_kapp_forms(updated_fields, conn, kapp_slugs, params={})
  params["include"]="pages, attributes, indexDefinitions"
  kapp_slugs.each do |kapp_slug|
    response = conn.find_forms(kapp_slug, params)

    response.content["forms"].each do |form| #This loops the Space/Kapp
      @logger.info("Processing the \"#{kapp_slug}\" form \"#{form["slug"]}\"")
  
      # flag to indicate the form contains at least one updated field
      update_form = false
      field_string = ",{\"name\":\"Discussion Id\",\"label\":\"Discussion Id\",\"type\":\"value\",\"visible\":false}"
      updated_fields.each do |field| #Loop all fields provided to find which need updates
        field.each do |name, properties| #Break field apart into name, properties
          update_required = false
          form["pages"].each do |page| #For each page iterate through to find elements
            
            page, updated_element = process_element(page, name)
            @logger.info("results from " + page['name'] + " - " + updated_element.to_s)
            if updated_element
              @logger.info("Update required from recursion")
              update_form = true
            end
          end
          @logger.info("Completed elements section")
          #ATTRIBUTES SECTION
          form["attributes"].each do |attribute|
            #break  attribute == []    
            if attribute == []
              next
            end
            @logger.info("looping attributes: " + attribute['name'])
            old_value = attribute['values'][0]
            attribute, update_required = process_attribute(attribute,field_string)
            @logger.info("Final value: " + attribute['values'][0])
            # update_form = true update_required
            if update_required
              update_form = true
            end
          end
          #INDEX DEFINITION SECTION
          @logger.info("Checking Index definitions")
          begin
            form["indexDefinitions"].each do |indexdefinition|
              # break  indexdefinition == []
              if indexdefinition == []
                @logger.info("Empty definition")
                next
              end
              @logger.info(indexdefinition['name'])
              requires_removal = false
              indexdefinition, requires_removal, updated_indexdefinition = process_indexDefinitions(indexdefinition, 'values[Discussion Id]')
              if requires_removal
                form['indexDefinitions'].delete(indexdefinition)
                @logger.info("Removed item from indexDefinitions")
                update_form = true
              end
              # update_form = true  updated_indexdefinition
              if updated_indexdefinition
                update_form = true
              end
            end #End IndexDefinitions do
          rescue => e
            @logger.info("Error running index check")
            @logger.error(e.message)
            next
          end
        end #End Name, Properties do
      end #End field do
  
      if update_form
        begin
          # update the form
          @logger.info("Updating the \"#{kapp_slug}\" form \"#{form["slug"]}\"")
          conn.update_form(kapp_slug, form["slug"], form)
          @logger.info("Completed update for #{kapp_slug} - #{form["slug"]}")
          @updated << { "slug" => form["slug"] }
        rescue StandardError => e
          @failed << { "slug" => form["slug"], "error" => e }
        end
      else
        @skipped << { "slug" => form["slug"] }
      end #End update_form if
    end #End form do
  
    # Process the next page of forms if there are more
    if !response.content["nextPageToken"].nil?
      params["pageToken"] = response.content["nextPageToken"]
      process_kapp_forms(updated_fields, conn, kapp_slug, params)
    end
  end #End iterating each kapp
end

# Setup logging
@logger = TeeLogger::TeeLogger.new(STDOUT, "#{PWD}/output.log")
@logger.level = config["LOG_LEVEL"].to_s.downcase == "debug" ? Logger::DEBUG : Logger::INFO

# Initalize the arrays that will hold the results
@updated, @skipped, @failed = [], [], []

# Create space connection
conn = KineticSdk::Core.new({
  space_server_url: config["SPACE_URL"],
  space_slug: config["SPACE_SLUG"],
  username: config["SPACE_USERNAME"],
  password: config["SPACE_PASSWORD"],
  options: { log_level: config["LOG_LEVEL"] }
})

# Process the forms
@logger.info("Processing forms in the \"#{kapp_slug}\" kapp")
process_kapp_forms(updated_fields, conn, kapp_slug, { "limit" => 100 })


# Log Results
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
