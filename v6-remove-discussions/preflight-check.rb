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
    export_directory: "#{DATA_DIR}/temp"
  },
})

logger.info "\n\n\n### Beginning Preflight Check for #{SPACE_SLUG}###"

# Compare two trees to see if they are the same
def trees_match?(current_doc, original_doc)
  current_nodes = current_doc.root.elements["taskTree/request"].elements.collect {|el| el.attributes["definition_id"]}.sort
  original_nodes = original_doc.root.elements["taskTree/request"].elements.collect {|el| el.attributes["definition_id"]}.sort
  return current_nodes == original_nodes
end

# Loop through trees that need to be modified and inspect diffs
modify["task"]["trees"].each do |tree|
  tree_title = tree["current"]
  original_filename = tree["filename"]

  # Fetch tree from current system
  current_tree = conn_task.find_tree(tree_title, { "include" => "export" })
  if current_tree.status == 404
    logger.warn "NOT FOUND: #{tree_title}"
  else
    # Parse Current and original tree (in data/originals folder)
    current_xml_doc = REXML::Document.new(current_tree.content["export"])
    original_xml_doc = REXML::Document.new(File.open("#{DATA_DIR}/originals/#{original_filename}", 'r'))
    match = trees_match?(current_xml_doc, original_xml_doc)
    # Log warning if tree doesn't match
    logger.warn "Tree: #{tree["current"]} does not match original" if !match
  end

end