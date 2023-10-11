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
task_path = "#{PWD}/task"

# setup logging
@logger = Logger.new("#{PWD}/output.log") #Output to file
# @logger = Logger.new(STDERR) #Output to screen
@logger.level = Logger::INFO

# Get the config files
config_file = "#{PWD}/config.yaml"
env = nil
begin
  env = YAML.load(ERB.new(open(config_file).read).result(binding))
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
    export_directory: "#{task_path}",
  },
})

# Create http connection
http = KineticSdk::CustomHttp.new({
  username: SPACE_USERNAME,
  password: SPACE_PASSWORD,
})

sources_to_process = []

# Export Scources and Trees as a backup
conn_task.export_sources()
conn_task.find_sources().content['sourceRoots'].each do |source|
  # Only update trees in the "Kinetic Request CE" sources
  if source['type'] == "Kinetic Request CE"
    sources_to_process.push(source['name'])
    conn_task.find_trees({ "source" => source['name'] }).content['trees'].each do |tree|
      conn_task.export_tree(tree['title'])
    end
  end
end

#
# BEGIN: Convert Trees to workflow and delete Legacy Trees
#

# Interate through each "Kinetic Request CE" source.
sources_to_process.each { |source_name|
  
  @logger.info "\r########################\rUpdating Trees in the \"#{source_name}\" source.\r########################"
  # Find all Trees
  trees = conn_task.find_trees({"source"=>source_name}).content['trees']

  # Iterate through the trees. Import relavent trees as a workflow and then delete it.
  trees.each{ |tree|
    # Get individual Tree
    tree_def = conn_task.find_tree(tree['title'], { "include" => "details,export" })
    
    # If "event" proprty is nil it will be a tree, otherwise it is a workflow and doens't need to be processed.
    if tree_def.content['event'].nil? 
      xml = tree_def.content['export']
      doc = Document.new(xml)
      root = doc.root
      source_name = "#{root.elements["sourceName"].text}"
      source_group = "#{root.elements["sourceGroup"].text}"      
      
      # Only process "Submission" Trees.
      if source_name.split(" > ")[0] == "Kinetic Request CE" && source_group.split(" > ")[0] != "WebApis"
        @logger.info "Processing tree: \"#{tree_def.content['title']}\""

        status = "#{root.elements["status"].text}"
        kapp_slug = source_group.split(" > ")[1]
        form_slug = source_group.split(" > ")[2]

        # Remove trailing "s" to singularize values such as "Submissions", "Forms", "Users"
        if source_group.split(" > ")[0].end_with?("s")
          event_preface = source_group.split(" > ")[0].chop
        else
          event_preface = source_group.split(" > ")[0]
        end
        
        # Remove "Datastore" From Source group and apply workflow to the "datstore" kapp
        if event_preface.match(/^Datastore\s/)
          @logger.info "\t Workflow is Datastore; modifying values"
          event_preface.gsub!(/^Datastore\s/, '')
          kapp_slug = "datastore"
          form_slug = source_group.split(" > ")[1]
        end

        # Set hash of values for the workflow import
        tree_name = "#{event_preface} #{root.elements["taskTree/name"].text}"        
        hash = {
          "name": "#{tree_name}",
          "event": "#{tree_name}",
          "treeXml": xml
        }

        # Output values
        @logger.info "\t status: #{status}"
        @logger.info "\t source_name: #{source_name}"
        @logger.info "\t source_group: #{source_group}"
        @logger.info "\t tree_name: #{tree_name}"
        @logger.info "\t kapp_slug: #{kapp_slug}"
        @logger.info "\t form_slug: #{form_slug}"

        # Appropriately import the workflow as a Form, Kapp, or Space Workflow
        if form_slug
          add_workflow_response = core_space.add_form_workflow(kapp_slug , form_slug, hash)
          @logger.info "\t Successfully added \"#{tree_name}\" Form Workflow for the \"#{form_slug}\" form in the \"#{kapp_slug}\" Kapp" if add_workflow_response.status == 200         
        elsif kapp_slug
          add_workflow_response = core_space.add_kapp_workflow(kapp_slug , hash)
          @logger.info "\t Successfully added \"#{tree_name}\" Kapp Workflow for the \"#{kapp_slug}\" Kapp" if add_workflow_response.status == 200         
        else
          add_workflow_response = core_space.add_space_workflow(hash)
          @logger.info "\t Successfully added \"#{tree_name}\" Space Workflow" if add_workflow_response.status == 200
        end
        
        # Log message if workflow didn't update
        if add_workflow_response.status != 200
          @logger.info "\t Workflow *NOT* added. (Response Code: #{add_workflow_response.status})"
          @logger.info "\t #{add_workflow_response.content['error']}" 
        end

        # Update status for "Inactive workflows"
        # There appears to be a bug that prevents the status of "Inactive" for imported Workflows.
        if add_workflow_response.status == 200 && status == "Inactive"
          # Set the url for the put method
          # Must us the put method in the SDK as an update_workflows method doesn't exit
          
          url = "#{SPACE_URL}/app/api/v1/"
          if form_slug
            url << "kapps/#{kapp_slug}/forms/#{form_slug}/workflows/#{add_workflow_response.content['id']}"
          elsif kapp_slug
            url << "kapps/#{kapp_slug}/workflows/#{add_workflow_response.content['id']}"
          else
            url << "workflows/#{add_workflow_response.content['id']}"
          end
          update_response = http.put(url, {"status":status}, http.default_headers)
          @logger.info "\t Successfully updated the workflow to Status of \"#{status}\"" if update_response.status == 200
        end

        # Delete the privious tree now that it has been imported as a Workflow
        if add_workflow_response.status == 200
          delete_repsonse = conn_task.delete_tree(tree_def.content['title'])
          @logger.info "\t Tree was successfully deleted." if delete_repsonse.status == 200
        end

      end
    end
  }
  @logger.info "Finished processing Trees"       
}

# Dir["#{task_path}/sources/kinetic-request-ce/trees/submissions*.xml"].each{ | file |

#   doc = Document.new(File.new(file))
#   root = doc.root
#   source_group = "#{root.elements["sourceGroup"].text}"
#   tree_name = "#{root.elements["taskTree/name"].text}"

#   kapp_slug = source_group.split(" > ")[1]
#   form_slug = source_group.split(" > ")[2]
#   hash = {
#     "name": "Submission #{tree_name}",
#     "event": "Submission #{tree_name}",
#     "treeXml": File.read(file)
#   }

#   if form_slug
#     @logger.info "Form: #{form_slug}"
#     core_space.add_form_workflow(kapp_slug , form_slug, hash)
#   elsif kapp_slug
#     @logger.info "Kapp: #{kapp_slug}"
#     core_space.add_kapp_workflow(kapp_slug , hash)
#   else
#     @logger.info "Space"
#     core_space.add_space_workflow(hash)
#   end

# }
## TODO ## 
