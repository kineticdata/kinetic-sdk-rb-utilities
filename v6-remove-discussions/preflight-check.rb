require "kinetic_sdk"
require "fileutils"
require "json"
require "yaml"
require "logger"
require "csv"
require "rexml/document"
require 'Find'
include REXML

# determine the present working directory
PWD = File.expand_path(File.dirname(__FILE__))
DATA_DIR = "#{PWD}/data"

# setup logging
logger = Logger.new("#{PWD}/output.log")
logger.level = Logger::INFO

# # Get the config files
# puts "Config name? (ex: config_file.yaml)"
# config_file_name = gets.chomp
# puts "Config: #{config_file_name}"

config_folder_path = File.join(PWD,'config')

if !File.directory?(config_folder_path)
  logger.info "Config folder not found at #{config_folder_path}"
  puts "Cannot find config folder!"
  puts "Exiting..."
  gets
  exit
end

# #Determine Config file to use
config_exts = ['.yaml','.yml']
configArray = []
logger.info "Checking #{config_folder_path} for config files"
begin
  Find.find("#{config_folder_path}/") do |file|
    logger.info "Checking #{file}"
    configArray.append(File.basename(file)) if config_exts.include?(File.extname(file))
  end
rescue
  logger.info "Error finding default config file path!"
  puts "Cannot find config files in default path! (#{pwd})"
  puts "Exiting script..."
  $stdin.gets
  exit
end
logger.info "Found config files"

puts "Select your config file"
configArray.each_with_index do |cFile, index|
  puts "#{index+1}) #{cFile}" 
end
logger.info "Sel section"
print "Selection: "
sel = $stdin.gets.chomp.to_i
begin
  configFile = configArray[sel-1]
  logger.info "Option #{sel} - #{configFile}"
rescue
  logger.info "Error selecting config file!"
  puts "Error selecting config file!"
  puts "Exiting..."
  gets
  exit
end


config_file = "#{config_folder_path}/#{configFile}"
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
LOG_LEVEL = env["LOG_LEVEL"]


#Function allows re-usability and added features
def ValidateField(field, defaultval)
  if !field.is_a?(String) || field === defaultval
    puts "Please enter #{defaultval}"
    field = gets.chomp
  end
  return field
end
# If username blank, prompt for password. This will NOT store in file
SPACE_USERNAME = ValidateField(env["SPACE_USERNAME"], 'USER')
# If password blank, prompt for password. This will NOT store in file
SPACE_PASSWORD = ValidateField(env["SPACE_PASSWORD"], 'PASSWORD')

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
  begin
    current_nodes = current_doc.root.elements["taskTree/request"].elements.collect {|el| el.attributes["definition_id"]}.sort
    original_nodes = original_doc.root.elements["taskTree/request"].elements.collect {|el| el.attributes["definition_id"]}.sort  
  rescue
    puts "Oops!"
    current_nodes = false
    original_nodes = false
  end
  #Second check, stripping out whitespace
  stripped_current_nodes = current_nodes.collect{ |e| e ? e.strip : e }
  stripped_original_nodes = original_nodes.collect{ |e| e ? e.strip : e }
  nodes_match = (current_nodes == original_nodes)
  stripped_nodes_match = (stripped_current_nodes == stripped_original_nodes)
  puts "Nodes match? #{nodes_match}"
  puts "Stripped nodes match? #{stripped_nodes_match}"
 return nodes_match
end

#Loops through "stock" trees that may contain "Discussions" - opens/closes files as needed
#treeToTest = "Kinetic Request CE :: Submissions > services > request-to-cancel :: Submitted"
# Loop through trees that need to be modified and inspect diffs

keyword = "Discussion"
modify["task"]["trees"].each do |tree|
  tree_title = tree["current"]
  original_filename = tree["filename"]
#  next if tree_title != treeToTest
#  treeR = tree
#  break
  # Fetch tree from current system
  current_tree = conn_task.find_tree(tree_title, { "include" => "export" })
  if current_tree.status == 404
    logger.warn "NOT FOUND: #{tree_title}"
  else
    # Parse Current and original tree (in data/originals folder)
    current_xml_doc = REXML::Document.new(current_tree.content["export"])
    original_xml_doc = REXML::Document.new(File.open("#{DATA_DIR}/originals/#{original_filename}", 'r'))
    current_contains_keyword = current_xml_doc.to_s.include?(keyword)
    if current_contains_keyword #See if keyword is in the string version of the doc, if not then skip
      match = trees_match?(current_xml_doc, original_xml_doc)
    else 
      puts "No keyword, skipping"
    end
    
    
    #includes = trees_include_word?(original_xml_doc, "Discussion")
    #puts ("Tree includes? " + includes.to_s)
    # Log warning if tree doesn't match
    logger.warn "Tree: #{tree["current"]} does not match original" if !match
  end
  
end