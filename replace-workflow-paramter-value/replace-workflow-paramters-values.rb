require "kinetic_sdk"
require 'logger'

# find the directory of this script
PWD = File.expand_path(File.dirname(__FILE__))

# load the connection configuration file
begin
  config = YAML.load_file( File.join(PWD, "config.yaml") )
rescue
  raise StandardError.new "There was a problem loading the config.yaml file"
end

logger = Logger.new(STDERR)
logger.level = Logger::INFO
logger.formatter = proc do |severity, datetime, progname, msg|
  date_format = datetime.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
  "[#{date_format}] #{severity}: #{msg}\n"
end


# Create space connection
conn = KineticSdk::Task.new({
  username: config["SPACE_USERNAME"],
  password: config["SPACE_PASSWORD"],
  app_server_url: "#{config["SPACE_URL"]}/app/components/task",
  options: {
	log_level: config["LOG_LEVEL"],
	log_output: "stderr"
  }
})

parameters = {
  "limit" => config["LIMIT"],
  "include" => "treeJson",
}

parameters["source"] = config["SOURCE"] if config["SOURCE"]
parameters["group"] = config["SOURCE_GROUP"] if config["SOURCE_GROUP"]
parameters["name"] = config["NAME"] if config["NAME"]
puts parameters

#Define value to find and replace  
find_value = config["FIND_VALUE"]   
replacement_value = config["REPLACEMENT_VALUE"]

# Get Trees
response =  conn.find_trees(parameters)

if response.content['trees'].length > 0
  puts "#{response.content['trees'].length} trees found"
  #Iterate through the trees
  response.content['trees'].each{ |tree|
    logger.info "Processing tree: #{tree['title']}"
    #Initialize updated to false
    updated = false 
    
    #Iterate through the nodes
    tree['treeJson']['nodes'].each do |node|
      #Iterate through the parameters and replace the value if it matches
      node['parameters'].each do |parameter|
        if parameter['value'] == find_value
          parameter['value'] = replacement_value 
          #Set updated to true
          updated = true
        end 
      end  
    end
    
    #Send the updated tree to Core if it was updated
    if updated
      update = conn.update_tree(tree['title'], tree)
      logger.info "\tUpdated tree." if update.status == 200
    else
      logger.info "\tTree was not updated."
    end
  }

else
	logger.info "No trees were found"

end
logger.info "Finished Processing"





