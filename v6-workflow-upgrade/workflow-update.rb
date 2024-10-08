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
@logger.info "\r########################\rBegin Script.\r########################"
@logger.info "\r######################## Exporting Trees. ########################"


sources_to_process = ["Kinetic Request CE"] # Only the "Kinetic Request CE" source

#
# BEGIN: Convert Trees to v6 workflow
#
@logger.info "\r######################## Begin Updating Trees ########################"

# Interate through each source.
sources_to_process.each { |source_name|
  
  @logger.info "Updating Trees in the \"#{source_name}\" source."
  # Find all Trees
  response = conn_task.find_trees({"source"=>source_name, "limit" => 1000}).content
  trees = response['trees']
  
  # Error if there are more than 1000 trees
  count = response['count'].to_i
  if count >= 1000
    puts "ERROR: #{count} trees were found. Only the first 1000 trees can be processed."
    puts "Code must be updated to handle additional trees."
    puts "EXITING"
    exit
  end  

  # Iterate through the treeas. Import relavent trees as a workflow.
  trees.each{ |tree|

  # Get individual Tree
    tree_def = conn_task.find_tree(tree['title'], { "include" => "details,export" })
    
    # If "event" proprty is nil it will be a tree, otherwise it is a workflow and doens't need to be processed.
    if tree_def.content['event'].nil? 
      
      # Export the tree as backup
      @logger.info "\t - Exporting the #{tree['title']} tree."
      conn_task.export_tree(tree['title'])
      
      # Define the trees to be converted
      tree_names_to_convert = ["Closed","Created", "Deleted","Saved","Submitted","Updated"]
      tree_source_types_to_convert = ["Datastore Submissions", "Datastore Forms","Forms","Submissions","Teams","Users"]
      
      xml = tree_def.content['export']
      source_name = tree_def.content['sourceName']
      source_group = tree_def.content['sourceGroup']      
      name = tree_def.content['name']

      # Process Tree skip
      # - Trees not in the Kinetic Request CE Source
      # - WebApis
      # - Trees that are not "Closed","Created", "Deleted","Submmitted","Updated"
      if source_name.split(" > ")[0] == "Kinetic Request CE" && tree_names_to_convert.include?(name) && tree_source_types_to_convert.include?(source_group.split(" > ")[0])
        @logger.info "Processing tree: \"#{tree_def.content['title']}\""

        status = tree_def.content['status']
        kapp_slug = source_group.split(" > ")[1]
        form_slug = source_group.split(" > ")[2]
        name = tree_def.content['name']

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
        tree_name = "#{event_preface} #{name}"        
        hash = {
          "name": "#{tree_name}",
          "event": "#{tree_name}",
          "treeXml": xml
        }

        # Output values
        @logger.info "\t status: #{status}"
        @logger.info "\t name: #{name}"
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
          # Must use the put method in the SDK as an update_workflows method doesn't exist
          
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

        # # This is dangerous as it will break any inflight processes.
        # # Delete the privious tree now that it has been imported as a Workflow
        # if add_workflow_response.status == 200 || add_workflow_response.status == 500
        #   delete_repsonse = conn_task.delete_tree(tree_def.content['title'])
        #   @logger.info "\t Tree was successfully deleted." if delete_repsonse.status == 200
        # end

        # Inactivate the trees. In activiation allows for inflight requests to complete but will not be used, even if the Webhooks exists.
        if add_workflow_response.status == 200 || add_workflow_response.status == 500
          delete_repsonse = conn_task.update_tree(tree_def.content['title'],{"status": "Inactive"})
          @logger.info "\t Tree was successfully updated." if delete_repsonse.status == 200
        end
      else
        @logger.info "Skipped tree: \"#{tree_def.content['title']}\""
      end
    end
  }
  @logger.info "\r########################\rScript Completed.\r########################"
}