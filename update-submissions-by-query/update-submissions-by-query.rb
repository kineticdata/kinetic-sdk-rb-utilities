require "kinetic_sdk"
require "optparse"
require "teelogger"
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

# Setup logging
@logger = TeeLogger::TeeLogger.new(STDOUT, "#{PWD}/output.log")
@logger.level = config["LOG_LEVEL"].to_s.downcase == "debug" ? Logger::DEBUG : Logger::INFO

# Create space connection
@conn = KineticSdk::Core.new({
  space_server_url: config["SERVER_URL"],
  #app_server_url: config["SPACE_URL"],
  space_slug: config["SPACE_SLUG"],
  username: config["SPACE_USERNAME"],
  password: config["SPACE_PASSWORD"],
  options: {
    log_level: config["LOG_LEVEL"],
    log_output: "stderr"
  }
})


# get submissions using createdAt value as workaround for pagination bug affecting > 1000 entries
def get_submissions(hash)
  kapp_slug   = hash["kapp_slug"]
  form_slug   = hash["form_slug"]
  limit       = hash["limit"]
                # Parameters must include details, orderBy, direction, and limit. Other includes and parmeters may be added.
  params      = {
                  "include"=>"details,values", 
                  "orderBy"=>"createdAt", 
                  "direction"=>"ASC", 
                  "limit" => limit, 
                }
  # Append createdAt to the Parameters if passed to method. (used by recursion to get next chunk/page)
  # Note: >= is used in order to account for possible submissions made at the same time. Therefore duplicate entries will also be found. Below duplicates are scrubbed.
  params["q"] = hash["q"] if !hash["q"].nil? 
  

  if params["q"].nil? && !hash["start_date"].nil?
    params["q"] = "createdAt>\"#{hash["start_date"]}\""
  elsif !params["q"].nil? && !hash["start_date"].nil?
    params["q"] += " AND createdAt>\"#{hash["start_date"]}\""
  end

  puts params

  response = @conn.find_form_submissions(kapp_slug, form_slug, params)
  # Extract the submissions from the response
  puts submissions = response.content['submissions']
  # If more submissions are found perform another query Else return to end queries
  if submissions.length <= limit && submissions.length != 0
    # Update Submissions
    submissions.each{ |submission| 
        @conn.patch_existing_submission(submission['id'], body={"values"=> hash['values']})
    }
    # Append the last/greated createdAt date as a starting date for the next query
     hash["start_date"] = (submissions.last)["createdAt"]
    # Recursively run the query
    get_submissions(hash)
  else
    # No more entries found return
    return 
  end

end

get_submissions({"kapp_slug" => config["KAPP_SLUG"], "form_slug" => config["FORM_SLUG"], "q" => config["QUERY"], "limit" => config["LIMIT"].to_i, "values" => config["VALUES"]})










puts "Finished"





