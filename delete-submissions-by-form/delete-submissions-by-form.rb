
require "kinetic_sdk"
require 'io/console'

require 'uri'
require 'net/http'
require 'json'
require "yaml"

PWD = File.expand_path(File.dirname(__FILE__))
config_file = "#{PWD}/delete-submissions-by-form/config.yaml"
env = nil
begin
  env = YAML.load(ERB.new(open(config_file).read).result(binding))
rescue => e
  logger.error "There was a problem loading the configuration files"
  exit
end

 # Delete a Submission
    #
    # @param kapp_slug [String] slug of the Kapp
    # @param form_slug [String] slug of the Form
    # @param payload [Hash] payload of the submission
    #   - +origin+ - Origin ID of the submission to be added
    #   - +parent+ - Parent ID of the submission to be added
    #   - +values+ - hash of field values for the submission
    #     - attachment fields contain an Array of Hashes. Each hash represents an attachment answer for the field. The hash must include a `path` property with a value to represent the local file location.)
    # @param parameters [Hash] hash of query parameters to append to the URL
    #   - +include+ - comma-separated list of properties to include in the response
    #   - +completed+ - signals that the submission should be completed, default is false
    # @param headers [Hash] hash of headers to send, default is basic authentication and accept JSON content type
    # @return [KineticSdk::Utils::KineticHttpResponse] object, with +code+, +message+, +content_string+, and +content+ properties
def delete_submission(kapp_slug, form_slug, submissionID, payload={}, parameters={}, headers=default_headers)
    puts "HI"
    # set origin hash if origin was passed as a string
    payload["origin"] = { "id" => payload["origin"] } if payload["origin"].is_a? String
    # set parent hash if parent was passed as a string
    payload["parent"] = { "id" => payload["parent"] } if payload["parent"].is_a? String
    # prepare any attachment values
    puts "pre"
    payload["values"] = prepare_new_submission_values(kapp_slug, form_slug, payload["values"])
    puts "post"
    # build the uri with the encoded parameters
    #uri = URI.parse("#{@api_url}/kapps/#{kapp_slug}/forms/#{form_slug}/submissions")
    uri = URI.parse("#{URL}/app/api/v1/submissions/#{submissionID}")
    uri.query = URI.encode_www_form(parameters) unless parameters.empty?
    # Delete the submission
    @logger.info("Deleting a submission with id \"#{submissionID}\" Form.")
    
    delete(uri.to_s, payload, headers)
end

#TEST
# SPACE_URL = "https://playground-travis-wiese.kinopsdev.io"
# SPACE_SLUG = "playground-travis-wiese"
# # KappSlug = "onboarding-project"
# # FormSlug = "initial-checklist"
# KappSlug = "queue"
# FormSlug = "work-order"
#END TEST

SPACE_URL = env["SPACE_URL"]
SPACE_SLUG = env["SPACE_SLUG"]
KappSlug = env["KAPP_SLUG"]
FormSlug = env["FORM_SLUG"]
SPACE_USERNAME = env["SPACE_USERNAME"]
SPACE_PASSWORD = env["SPACE_PASSWORD"]
LOG_LEVEL = env["LOG_LEVEL"]
FILTER = env["FILTER"]

#SPACE_USERNAME = puts "Enter Username: "
#SPACE_PASSWORD = IO::console.getpass "Enter Password: "
# SPACE_USERNAME = "Travis.Wiese@kineticdata.com"
# SPACE_PASSWORD = ------
# LOG_LEVEL = "info"
DATA_DIR = "C:/temp"


#Create Header
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

  conn_task = KineticSdk::Task.new({
    username: SPACE_USERNAME,
    password: SPACE_PASSWORD,
    app_server_url: "#{SPACE_URL}/app/components/task",
    options: {
      log_level: LOG_LEVEL,
      export_directory: "#{DATA_DIR}/temp"
    },
  })

# Request URL
##{URL}/app/api/v1/kapps/#{KappSlug}/forms/#{FormSlug}/submissions?direction=DESC&limit=25&include=values
if FILTER != ''
    begin
        paramsFilter = {'q': FILTER}
        Submissions = core_space.find_form_submissions(KappSlug,FormSlug, paramsFilter).content["submissions"]
    rescue
        logger.error("There was an error attempting to query with the applied filter")
        logger.error("Kapp: #{KappSlug} - Form: #{FormSlug}")
        logger.error("Filter: #{Filter}")
        logger.error("Exiting...")
        gets
        exit
    end
else
    begin
        Submissions = core_space.find_form_submissions(KappSlug,FormSlug).content["submissions"]
    rescue
        logger.error("There was an error attempting to query with no filter")
        logger.error("Kapp: #{KappSlug} - Form: #{FormSlug}")
        logger.error("Exiting...")
        gets
        exit
    end

    
end

#TODO - Add filter options to qualify which submissions, if blank then grab all


# Submissions.each do |s|
#     puts s["id"]
# end
#Loop through each submission
Submissions.each do |s|
    begin
        puts "Deleting submission with ID #{s["id"]}"
        uri = URI.parse("#{SPACE_URL}/app/api/v1/submissions/#{s["id"]}")
        # req = Net::HTTPS::Get.new(uri, initheader = {'Content-Type' =>'application/json'})
        req = Net::HTTP::Delete.new(uri, initheader = {'Content-Type' =>'application/json'})
        req.basic_auth(SPACE_USERNAME, SPACE_PASSWORD)
        res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) {|http|
            http.request(req)
        }
        puts res.body
    rescue StandardError => e
        puts "Error looping!"
        puts e
        break
    end
end

