require "kinetic_sdk"
require "optparse"
require "teelogger"
require 'logger'

# find the directory of this script
PWD = File.expand_path(File.dirname(__FILE__))

# load the @connection @configuration file
begin
  @config = YAML.load_file( File.join(PWD, "config.yaml") )
rescue
  raise StandardError.new "There was a problem loading the @config.yaml file"
end

# logger = Logger.new(STDERR)
# logger.level = Logger::INFO
# logger.formatter = proc do |severity, datetime, progname, msg|
  # date_format = datetime.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
  # "[#{date_format}] #{severity}: #{msg}\n"
# end

# Setup logging
@logger = TeeLogger::TeeLogger.new(STDOUT, "#{PWD}/output.log")
@logger.level = @config["LOG_LEVEL"].to_s.downcase == "debug" ? Logger::DEBUG : Logger::INFO

# Create space @connection
@conn = KineticSdk::Core.new({
  space_server_url: @config["SERVER_URL"],
  #app_server_url: @config["SPACE_URL"],
  space_slug: @config["SPACE_SLUG"],
  username: @config["SPACE_USERNAME"],
  password: @config["SPACE_PASSWORD"],
  options: {
    log_level: @config["LOG_LEVEL"],
    log_output: "stderr"
  }
})

# Create space @connection
@http_conn = KineticSdk::CustomHttp.new({
  username: @config["SPACE_USERNAME"],
  password: @config["SPACE_PASSWORD"],
  options: {
	log_level: @config["LOG_LEVEL"],
	log_output: "stderr"
  }
})

@parameters = {
  "type" => @config["TYPE"],
  "coreState" => @config["CORESTATE"],
  "q" => (@config["QUERY"] if @config["QUERY"]),
  "direction" => "DESC",
  "limit" => @config["LIMIT"],
  "include" => "values"
}.compact

def perform_query
  # Get Submissions
  if !@config["FORM_SLUG"].nil?
    @response =  @conn.find_form_submissions(@config["KAPP_SLUG"], @config["FORM_SLUG"], @parameters)
  else
    @response =  @conn.find_kapp_submissions(@config["KAPP_SLUG"], @parameters)
  end
end

# Execute the query
perform_query

# Check if any submissions were found
if @response.content['submissions'].length > 0
	# Confirm delete action with the user
  puts "#{@response.content['submissions'].length} submissions were found on #{@config["SERVER_URL"]}."
	puts "Would you like to DELETE them *ALL*? (Y/N)"
	STDOUT.flush
	case (gets.downcase.chomp)
	when 'y'
	  puts "Deleting Submissions"
	  STDOUT.flush
	else
	  abort "Exiting"
	end
  
  # Continue to search until a nextPageToken is empty which indicates the last page of search results.
  while @response.content['nextPageToken']
    # Delete Submissions
    @response.content['submissions'].each{ |submission| 
      @http_conn.delete("#{@config['SERVER_URL']}/app/api/v1/submissions/#{submission['id']}", @http_conn.default_headers)
    }
    @parameters['pageToken'] = @response.content['nextPageToken']
    perform_query
  end
else
	puts "No submissions were found"
	STDOUT.flush
end
puts "Finished"





