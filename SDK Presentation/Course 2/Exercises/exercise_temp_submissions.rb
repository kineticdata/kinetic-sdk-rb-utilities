require "kinetic_sdk"
require "optparse"
require 'logger'

# find the directory of this script
PWD = File.expand_path(File.dirname(__FILE__))

# load the connection configuration file
# begin
#   config = YAML.load_file( File.join(PWD, "config.yaml") )
# rescue
#   raise StandardError.new "There was a problem loading the config.yaml file"
# end

# @logger = Logger.new(STDOUT)
@logger = Logger.new('logfile.log')
@logger.level = Logger::INFO
@logger.formatter = proc do |severity, datetime, progname, msg|
  date_format = datetime.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
  "[#{date_format}]:#{severity} #{msg}\n"
end

# Create space connection
@conn = KineticSdk::Core.new({
  space_server_url: "",
  space_slug: "",
  username: "",
  password: "",
  options: {
      log_level: "INFO",
      log_output: "stdout"
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

  # puts @conn.pretty_inspect
  @logger.error params
  response = @conn.find_form_submissions(kapp_slug, form_slug) #, params)
  # Extract the submissions from the response
  puts submissions = response.content['submissions']
  # If more submissions are found perform another query Else return to end queries
  if submissions.length <= limit && submissions.length != 0
    # Update Submissions
    submissions.each{ |submission| 
        # @conn.patch_existing_submission(submission['id'], body={"values"=> hash['values']})
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

get_submissions({"kapp_slug" => "services", "form_slug" => "anonymous-test", "q" => "", "limit" => """".to_i, "values" => ""})








puts "Finished"





