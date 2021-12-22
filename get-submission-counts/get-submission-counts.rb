require "kinetic_sdk"
require "optparse"
require "logger"
require "csv"
require "parallel"

# find the directory of this script
PWD = File.expand_path(File.dirname(__FILE__))

# Setup logging
LOGGER = Logger.new("#{PWD}/output.log")
LOGGER.level = Logger::INFO

# Parse script options
options = {}
OptionParser.new do |opts|
  opts.on("--kapp [Kapp Slug]", "Kapp slug") do |v|
    options[:kapp_slug] = v
  end
  opts.on("--form [Form Slug]", "Form slug") do |v|
    options[:form_slug] = v
  end
  opts.on("--datastore [Datastore]", "Datastore") do |v|
    options[:datastore] = v
  end
end.parse!

KAPP_SLUG = options[:kapp_slug]
FORM_SLUG = options[:form_slug]
DATASTORE = options[:datastore]


# load the connection configuration file
begin
  config = YAML.load_file( File.join(PWD, "config.yaml") )
rescue
  raise StandardError.new "There was a problem loading the config.yaml file"
end

# Create space connection
CORE_SDK = KineticSdk::Core.new({
  space_server_url: config["SPACE_URL"],
  space_slug: config["SPACE_SLUG"],
  username: config["SPACE_USERNAME"],
  password: config["SPACE_PASSWORD"],
  options: { log_level: config["LOG_LEVEL"] }
})

# Fetch Version of Core
CORE_VERSION = CORE_SDK.app_version.content["version"]["version"].to_f
KAPP_CORE_STATES = ["Draft", "Submitted", "Closed"]
DATASTORE_CORE_STATES = ["Draft", "Submitted"]
LIMIT = 1000
SUBMISSION_COUNTS = []

# Helper method for counting actual submissions and writing them to gloabl array.
# Purpously not using the find all submissions methods in the SDK as they keep all submissions in memory
# and we only need the counts

# TODO - Time bucket closed submissions by month to make the queries more efficient on the server
def count_submissions(query)
  kapp_slug = query["kapp_slug"]
  form_slug = query["form_slug"]
  datastore = query["datastore"]
  counts = []
  if datastore
    counts = Parallel.map(DATASTORE_CORE_STATES) do |coreState|
      params = {"coreState" => coreState, "limit" => LIMIT}
      response = CORE_SDK.find_form_datastore_submissions(form_slug, params)
      count = response.content["submissions"].size

      while (!response.content["nextPageToken"].nil?)
        params['pageToken'] = response.content["nextPageToken"]
        response = CORE_SDK.find_form_datastore_submissions(form_slug, params)
        count += response.content["submissions"].size
      end
      count
    end
  else
    counts = Parallel.map(KAPP_CORE_STATES) do |coreState|
      params = {"coreState" => coreState, "limit" => LIMIT}
      response = CORE_SDK.find_form_submissions(kapp_slug, form_slug, params)
      count = response.content["submissions"].size

      while (!response.content["nextPageToken"].nil?)
        params['pageToken'] = response.content["nextPageToken"]
        response = CORE_SDK.find_form_submissions(kapp_slug, form_slug, params)
        count += response.content["submissions"].size
      end
      count
    end
  end
  SUBMISSION_COUNTS.push({"kapp_slug" => datastore ? "datastore" : kapp_slug, "form_slug" => form_slug, "count" => counts.sum})
end

# Method to return count of all submissions for a given kapp form
def count_kapp_form_submissions(kapp_slug, form_slug)
  count_submissions({"kapp_slug" => kapp_slug, "form_slug" => form_slug})
end

# Method to return count of all submissions for a given datastore form
def count_datastore_form_submissions(form_slug)
  count_submissions({"datastore" => true, "form_slug" => form_slug})
end

# Method to return count of all submissions for a given datastore form
def count_all_datastore_form_submissions
  form_slugs = CORE_SDK.find_datastore_forms().content["forms"].map { |form| form["slug"]}
  form_slugs.each do |form_slug|
    count_datastore_form_submissions(form_slug)
  end
end

# Method to return count of all submissions in a given kapp
def count_single_kapp_submissions(kapp_slug)
  form_slugs = CORE_SDK.find_forms(kapp_slug).content["forms"].map { |form| form["slug"]}
  form_slugs.each do |form_slug|
    count_submissions({"kapp_slug" => kapp_slug, "form_slug" => form_slug})
  end
end

# method to return all submissions regardless of kapp
def count_all_kapp_submissions()
  kapp_slugs = CORE_SDK.find_kapps().content["kapps"].map { |kapp| kapp["slug"]}
  kapp_slugs.each do |kapp_slug|
    count_single_kapp_submissions(kapp_slug)
  end
end

# Determine What to Count and call the appropriate method
if KAPP_SLUG && !FORM_SLUG
  LOGGER.info "Counting all #{KAPP_SLUG} kapp submissions"
  count_single_kapp_submissions(KAPP_SLUG)
elsif KAPP_SLUG && FORM_SLUG 
  LOGGER.info "Counting all #{FORM_SLUG} submissions in the #{KAPP_SLUG} kapp"
  count_kapp_form_submissions(KAPP_SLUG, FORM_SLUG)
elsif DATASTORE && !FORM_SLUG
  LOGGER.info "Counting all datastore submissions"
  count_all_datastore_form_submissions()
elsif DATASTORE && FORM_SLUG
  LOGGER.info "Counting all #{FORM_SLUG} datastore submissions"
  count_datastore_form_submissions(FORM_SLUG)
else
  LOGGER.info "Counting all submissions in the system"
  count_all_kapp_submissions()
  count_all_datastore_form_submissions()
end

# Write output.csv file for submission counts of each form
CSV.open(File.join(PWD, "output.csv"), "wb") do |csv|
  csv << SUBMISSION_COUNTS.first.keys # adds the column names on the first line
  SUBMISSION_COUNTS.each do |hash|
    csv << hash.values
  end
end