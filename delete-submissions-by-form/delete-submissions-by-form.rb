
require "kinetic_sdk"
require 'io/console'

require 'uri'
require 'net/http'
require 'json'
require "yaml"

PWD = File.expand_path(File.dirname(__FILE__))

#Detect if running in irb and adjust for dev testing
if __FILE__ == "(irb)"
  #PWDirb
  PWD = PWD + "/delete-submissions-by-form"
end

config_file = "#{PWD}/config-sandbox.yaml"

logger = Logger.new("#{PWD}/output.log")
logger.level = Logger::INFO

env = nil
begin
  env = YAML.load(ERB.new(open(config_file).read).result(binding))
rescue => e
  logger.error "There was a problem loading the configuration files"
  gets
  exit
end

SPACE_URL = env["SPACE_URL"]
SPACE_SLUG = env["SPACE_SLUG"]
KappSlug = env["KAPP_SLUG"]
FormSlug = env["FORM_SLUG"]
SPACE_USERNAME = env["SPACE_USERNAME"]
SPACE_PASSWORD = env["SPACE_PASSWORD"]
LOG_LEVEL = env["LOG_LEVEL"]
FILTER = env["FILTER"]
DATA_DIR = "#{PWD}/data"

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
        params = {'limit': 1000}
        Submissions = core_space.find_form_submissions(KappSlug,FormSlug, params).content["submissions"]
    rescue
        logger.error("There was an error attempting to query with no filter")
        logger.error("Kapp: #{KappSlug} - Form: #{FormSlug}")
        logger.error("Exiting...")
        gets
        exit
    end
end

#TODO - Can I add logic to handle submissions with children? 
#include=children
#Loop array to remove
#Check for inf recursion down
#Loop through each submission


Submissions.each do |s|
  begin
      logger.info("Deleting submission with ID #{s["id"]}")
      res = core_space.delete_submission(s["id"])
      logger.info(res.code)
      logger.info(res.content)
  rescue StandardError => e
      logger.error("Error looping!")
      logger.error(e)
      logger.info("Moving onto next item")
      continue
  end
end
#OLD WAY




# Submissions.each do |s|
#     begin
#         logger.info("Deleting submission with ID #{s["id"]}")
#         uri = URI.parse("#{SPACE_URL}/app/api/v1/submissions/#{s["id"]}")
#         # uri = URI.parse("#{SPACE_URL}/#/kapps/#{KappSlug}/forms/#{FormSlug}/#{s["id"]}")
#         # req = Net::HTTP::Get.new(uri, initheader = {'Content-Type' =>'application/json'})
#         req = Net::HTTP::Delete.new(uri, initheader = {'Content-Type' =>'application/json'})
#         req.basic_auth(SPACE_USERNAME, SPACE_PASSWORD)
#         res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) {|http|
#             http.request(req)
#         }
#         logger.info(res.body)
#     rescue StandardError => e
#         logger.error("Error looping!")
#         logger.error(e)
#         logger.info("Moving onto next item")
#         continue
#     end
# end

