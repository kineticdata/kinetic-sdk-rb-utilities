
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
  PWD = PWD + "/delete-submissions-by-form" if !PWD.include?("/delete-submissions-by-form")
end

#List config file here
config_file = "#{PWD}/config.yaml"

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

@SPACE_URL = env["SPACE_URL"]
@SPACE_SLUG = env["SPACE_SLUG"]
@KappSlug = env["KAPP_SLUG"]
@FormSlug = env["FORM_SLUG"]
@SPACE_USERNAME = env["SPACE_USERNAME"]
@SPACE_PASSWORD = env["SPACE_PASSWORD"]
@LOG_LEVEL = env["LOG_LEVEL"]
@FILTER = env["FILTER"]
DATA_DIR = "#{PWD}/data"
@default_params = {'limit': 1000, 'include': 'details', 'direction': "ASC"}
#Create Header
@core_space = KineticSdk::Core.new({
    space_server_url: @SPACE_URL,
    space_slug: @SPACE_SLUG,
    username: @SPACE_USERNAME,
    password: @SPACE_PASSWORD,
    options: {
      log_level: @LOG_LEVEL,
      max_redirects: 3,
    },
  })

  @conn_task = KineticSdk::Task.new({
    username: @SPACE_USERNAME,
    password: @SPACE_PASSWORD,
    app_server_url: "#{@SPACE_URL}/app/components/task",
    options: {
      log_level: @LOG_LEVEL,
      export_directory: "#{DATA_DIR}/temp"
    },
  })

# Request URL
##{URL}/app/api/v1/kapps/#{KappSlug}/forms/#{FormSlug}/submissions?direction=DESC&limit=25&include=values
@SubmissionList = []
def Find_Submissions(params = @default_params)
  filter = params[:q] if !params[:q].nil?
  loop do
    response = @core_space.find_form_submissions(@KappSlug,@FormSlug, params)
      response.content["submissions"].each do |r|
        @SubmissionList.append(r)
      end
      if response.content["submissions"].length == 1000
        if filter
          params[:q] = "#{filter}&createdAt>=\"#{response.content["submissions"][999]["createdAt"]}\""
        else
          params[:q] = "createdAt>=\"#{response.content["submissions"][999]["createdAt"]}\""
        end

      else
        return "HI"
      end
    end
end

if @FILTER != ''
    begin
        paramsFilter = @default_params
        paramsFilter[:q] = @FILTER
        loop do
          if @FormSlug
            response = @core_space.find_form_submissions(@KappSlug,@FormSlug, paramsFilter)
          else
            response = @core_space.find_kapp_submissions(@KappSlug, paramsFilter)
          end
          response.content["submissions"].each do |r|
            @SubmissionList.append(r)
          end
          if @SubmissionList.length == 1000
            paramsFilter[:q] = "#{@FILTER}&createdAt>=\"#{@SubmissionList[999]["createdAt"]}"
          end
          break if response.content['nextPageToken'] == nil
        end
        
    rescue
        logger.error("There was an error attempting to query with the applied filter")
        logger.error("Kapp: #{@KappSlug} - Form: #{@FormSlug}")
        logger.error("Filter: #{@Filter}")
        logger.error("Exiting...")
        gets
        exit
    end
else
    begin
        params = {'limit': 1000, 'include': 'values, details'}
        pageToken = ''
        loop do
          if @FormSlug
            response = @core_space.find_form_submissions(@KappSlug,@FormSlug, params)
          else
            response = @core_space.find_kapp_submissions(@KappSlug, params)
          end
          #Set NextPageToken
          pageToken = response.content["nextPageToken"]
          params[:pageToken] = pageToken
          #Grab Responses in this query
          response.content["submissions"].each do |r|
            @SubmissionList.append(r)
          end
          puts "NPT: #{response.content["nextPageToken"]}"
          if @SubmissionList.length == 1000
            paramsFilter[:q] = "createdAt>=\"#{@SubmissionList[999]["createdAt"]}"
          end
          break if pageToken == nil
        end    
    rescue
        logger.error("There was an error attempting to query with no filter\nKapp: #{KappSlug} - Form: #{FormSlug}")
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


@SubmissionList.each do |s|
  begin
      logger.info("Deleting submission with ID #{s["id"]}")
      res = @core_space.delete_submission(s["id"])
      logger.info(res.code)
      logger.info(res.content)
  rescue StandardError => e
      logger.error("Error looping!")
      logger.error(e)
      logger.info("Moving onto next item")
      continue
  end
end