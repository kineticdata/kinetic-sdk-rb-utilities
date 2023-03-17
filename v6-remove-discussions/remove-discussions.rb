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
logger = Logger.new("#{PWD}/output.log")
logger.level = Logger::INFO

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
  logger.error "There was a problem loading the configuration files"
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

logger.info "\n\n\n### Beginning Migration for #{SPACE_SLUG}###"

# # Loop through trees that need to be modified and inspect diffs
# logger.info "Beginning Modification of trees"
# modify["task"]["trees"].each do |tree|
#   tree_title = tree["current"]
#   new_tree_filename = tree["filename"]
#   # Fetch tree from current system
#   current_tree = conn_task.find_tree(tree_title)
#   if current_tree.status == 404
#     logger.info "NOT FOUND: Tree #{tree_title} was not found and therefore not modified."
#     break
#   else
#     # Import updated tree
#     modified_tree = File.open("#{DATA_DIR}/modifications/#{new_tree_filename}", "r")
#     import = conn_task.import_tree(modified_tree, true)
#     # Log Outcome
#     logger.warn "Tree: #{tree["current"]} does not match original" if import.status != 200
#     logger.info "Trees successfully modified" if import.status == 200
#   end
# end

# # Delete Trees
# delete["task"]["trees"].each do |tree_title|
#   conn_task.delete_tree(tree_title)
#   logger.info "Trees successfully deleted"
# end

# # Delete Routines
# delete["task"]["routines"].each do |routine_name|
#   conn_task.delete_tree({
#     "source_name" => "-",
#     "group_name" => "-",
#     "tree_name" => routine_name,
#   })
#   logger.info "Routines successfully deleted"
# end

# # Delete API Handler
# delete["task"]["handlers"].each do |handler_def_id|
#   conn_task.delete_handler(handler_def_id)
#   logger.info "Handlers successfully deleted"
# end

# # Delete Task Source
# delete["task"]["sources"].each do |source_name|
#   conn_task.delete_source(source_name)
#   logger.info "Sources successfully deleted"
# end

# # Delete Space Webhooks
# delete["space"]["webhooks"].each do |name|
#   core_space.delete_webhook_on_space(name)
#   logger.info "Space webhooks successfully deleted"
# end

# # Delete Space Attributes
# delete["space"]["attributes"].each do |name|
#   core_space.delete_space_attribute_definition(name)
#   logger.info "Space attributes successfully deleted"
# end

# # Delete Space Attributes
# delete["teams"]["attributes"].each do |name|
#   core_space.delete_team_attribute_definition(name)
#   logger.info "Team attributes successfully deleted"
# end

# Cleanup Kapps
kapp_slugs = core_space.find_kapps.content["kapps"].collect{|k| k["slug"]}
kapp_slugs.each do |kapp|
  # Delete Kapp Attributes
  delete["kapps"]["attributes"]["kapp"].each do |name|
    core_space.delete_kapp_attribute_definition(kapp, name)
    logger.info "Kapp #{kapp} kapp attributes successfully deleted"
  end
  # Delete Category Attributes
  delete["kapps"]["attributes"]["category"].each do |name|
    core_space.delete_category_attribute_definition(kapp, name)
    logger.info "Kapp #{kapp} category attributes successfully deleted"
  end
  # Delete Form Attributes
  delete["kapps"]["attributes"]["form"].each do |name|
    core_space.delete_form_attribute_definition(kapp, name)
    logger.info "Kapp #{kapp} form attributes successfully deleted"
  end
end

## TODO ## - Remove Discussion ID from all forms??