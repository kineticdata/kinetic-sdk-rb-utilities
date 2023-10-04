require "kinetic_sdk"
require "fileutils"
require "json"
require "yaml"
require "logger"
require "csv"
require "rexml/document"
include REXML


# determine the present working directory
PWD = File.expand_path(File.dirname(__FILE__))
DATA_DIR = "#{PWD}/data"

# setup logging
@logger = Logger.new("#{PWD}/output.log")
@logger.level = Logger::INFO

# Get the config files
config_file = "#{PWD}/config.yaml"
delete_file = "#{PWD}/data/delete-config.yaml"
modify_file = "#{PWD}/data/modify-config.yaml"
env = nil
begin
  env = YAML.load(ERB.new(open(config_file).read).result(binding))
  delete = YAML.load(ERB.new(open(delete_file).read).result(binding))
  modify = YAML.load(ERB.new(open(modify_file).read).result(binding))
rescue => e
  @logger.error "There was a problem loading the configuration files"
  exit
end

# load config from config file
SPACE_URL = env["SPACE_URL"]
SPACE_SLUG = env["SPACE_SLUG"]
SPACE_USERNAME = env["SPACE_USERNAME"]
SPACE_PASSWORD = env["SPACE_PASSWORD"]
LOG_LEVEL = env["LOG_LEVEL"]

# create space connection
core_space = KineticSdk::Core.new({
  space_server_url: SPACE_URL,
  space_slug: SPACE_SLUG,
  username: SPACE_USERNAME,
  password: SPACE_PASSWORD,
  options: {
    log_level: LOG_LEVEL,
    max_redirects: 3,
  },
})

# Create space connection
conn_task = KineticSdk::Task.new({
  username: SPACE_USERNAME,
  password: SPACE_PASSWORD,
  app_server_url: "#{SPACE_URL}/app/components/task",
  options: {
    log_level: LOG_LEVEL,
    export_directory: "#{DATA_DIR}/temp",
  },
})

# Compare two trees to see if they are the same
def trees_match?(current_doc, original_doc)
  current_nodes = current_doc.root.elements["taskTree/request"].elements.collect {|el| el.attributes["definition_id"]}.sort
  original_nodes = original_doc.root.elements["taskTree/request"].elements.collect {|el| el.attributes["definition_id"]}.sort
  return current_nodes == original_nodes
end

# def log_output(name, item, kapp_or_space, action, status)
def log_output(args)
  args['kapp_or_space'] = (!args['kapp_or_space'].nil? && !args['kapp_or_space'].empty? ? "\"#{args['kapp_or_space']}\" "  : nil)
  if args['status'] == 200
    @logger.info "The #{args['kapp_or_space']}#{args['item']} \"#{args['name']}\" was successfully #{args['action']}." 
  elsif args['status'] == 404
    @logger.info "The #{args['kapp_or_space']}#{args['item']} \"#{args['name']}\" was not found."
  else  
    @logger.error "Error: #{args['status']} for #{args['kapp_or_space']}#{args['item']} #{args['name']}"
  end
end

@logger.info "\n\n\n### Beginning Migration for #{SPACE_URL}###"

# create folder to write submission data to
FileUtils.mkdir_p("#{PWD}/data/previous/", :mode => 0700)

# Loop through trees that need to be modified and inspect diffs
@logger.info "### Beginning Modification of trees ###"

modify["task"]["trees"].each do |tree|
  tree_title = tree["current"]
  original_filename = tree["filename"]

  @logger.info "Tree: #{tree_title}"

  # Fetch tree from current system
  current_tree = conn_task.find_tree(tree_title, { "include" => "export" })
  
  if current_tree.status == 404
    @logger.info "\tTREE NOT FOUND"
  else
    # Parse Current and original tree (in data/originals folder)
    current_xml_doc = REXML::Document.new(current_tree.content["export"])
    original_xml_doc = REXML::Document.new(File.open("#{DATA_DIR}/originals/#{original_filename}", 'r'))
    match = trees_match?(current_xml_doc, original_xml_doc)
    # Log if tree doesn't match
    @logger.info "\tTree does not match original. No changes were made." if !match

    # write the file
    filename = "#{PWD}/data/previous/#{original_filename}"
    File.open(filename, 'w') { |file| file.write(current_xml_doc) }

    if match
      # Import updated tree
      @logger.info "\tReplacing Tree."
      modified_tree = File.open("#{DATA_DIR}/modifications/#{original_filename}", "r")
     import = conn_task.import_tree(modified_tree, true)
      # Log Outcome
     @logger.info "\tError: #{import.status}.When importing " if import.status != 200
     @logger.info "\tTree successfully modified" if import.status == 200
    end

  end
end

@logger.info "### Starting Deletions for #{SPACE_SLUG}###"

# Delete Trees
delete["task"]["trees"].each do |tree_title|
  request = conn_task.delete_tree(tree_title)
  log_output({"name"=>tree_title, "item"=>"tree", "kapp_or_space"=>"", "action"=>"deleted", "status"=>request.status})
end

# Delete Routines
delete["task"]["routines"].each do |routine_name|
  request = conn_task.delete_tree({
    "source_name" => "-",
    "group_name" => "-",
    "tree_name" => routine_name,
  })
  log_output({"name"=>routine_name, "item"=>"Routine", "action"=>"deleted", "status"=>request.status})
end

# Delete Handlers
delete["task"]["handlers"].each do |handler_def_id|
  request = conn_task.delete_handler(handler_def_id)
  log_output({"name"=>handler_def_id, "item"=>"Handler", "action"=>"deleted", "status"=>request.status})
end

# Delete Task Source
delete["task"]["sources"].each do |source_name|
  request = conn_task.delete_source(source_name)
  log_output({"name"=>source_name, "item"=>"Source", "action"=>"deleted", "status"=>request.status})
end

# Delete Task Categories
delete["task"]["categories"].each do |task_category|
  request = conn_task.delete_category(task_category)
  log_output({"name"=>task_category, "item"=>"Task Categories", "action"=>"deleted", "status"=>request.status})
end

# Delete Space Attributes Definitions
delete["space"]["attributes"].each do |name|
  request = core_space.delete_space_attribute_definition(name)
  log_output({"name"=>name, "item"=>"Space Attribute", "kapp_or_space"=> "Space", "action"=>"deleted", "status"=>request.status})
end

# Delete Team Attributes Definitions
delete["teams"]["attributes"].each do |name|
  request = core_space.delete_team_attribute_definition(name)
  log_output({"name"=>name, "item"=>"Team Attribute", "kapp_or_space"=> "Space", "action"=>"deleted", "status"=>request.status})
end

# Delete Space Webhooks
delete["space"]["webhooks"].each do |webhook| 
  request = core_space.delete_webhook_on_space(webhook)
  log_output({"name"=>webhook, "item"=>"Webhook", "kapp_or_space"=> "Space", "action"=>"deleted", "status"=>request.status})
end

# Cleanup Kapps
kapp_slugs = core_space.find_kapps.content["kapps"].collect{|k| k["slug"]}

kapp_slugs.each do |kapp|
  # Delete Kapp Attributes
  delete["kapps"]["attributes"]["kapp"].each do |name|
    request = core_space.delete_kapp_attribute_definition(kapp, name)
    log_output({"name"=>name, "item"=>"Kapp Attribute", "kapp_or_space"=>kapp, "action"=>"deleted", "status"=>request.status})
  end
  
  # Delete Category Attributes
  delete["kapps"]["attributes"]["category"].each do |name|
    request = core_space.delete_category_attribute_definition(kapp, name)
    log_output({"name"=>name, "item"=>"Category Attribute", "kapp_or_space"=>kapp, "action"=>"deleted", "status"=>request.status})
  end
  
  # Delete Form Attributes
  delete["kapps"]["attributes"]["form"].each do |name|
    request = core_space.delete_form_attribute_definition(kapp, name)
    log_output({"name"=>name, "item"=>"Form Attribute", "kapp_or_space"=>kapp, "action"=>"deleted", "status"=>request.status})
  end
  
end

## TODO ## 
#- Remove Discussion ID fields from all forms??
#- Remove Discussion ID attribute values from all forms??