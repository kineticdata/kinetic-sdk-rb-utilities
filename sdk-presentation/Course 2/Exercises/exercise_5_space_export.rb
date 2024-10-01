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
conn_core = KineticSdk::Core.new({
  space_server_url: config["SERVER_URL"],
  space_slug: config["SPACE_SLUG"],
  username: config["SPACE_USERNAME"],
  password: config["SPACE_PASSWORD"],
  options: {
    log_level: config["LOG_LEVEL"],
    export_directory: "#{PWD}/core"
  }
})

# Export Core Components
conn_core.export_space()

# ------------------------------------------------------------------------------
# Task
# ------------------------------------------------------------------------------

# Create task connection
conn_task = KineticSdk::Task.new({
  space_server_url: config["SERVER_URL"]+"/app/components/task",
  space_slug: config["SPACE_SLUG"],
  username: config["SPACE_USERNAME"],
  password: config["SPACE_PASSWORD"],
  options: {
    log_level: config["LOG_LEVEL"],
    export_directory: "#{PWD}/task"
  }
})

# Export Task Comonents
conn_task.export()