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


# get submissions using createdAt value as workaround for pagination bug affecting > 1000 entries
def get_submissions(query)
  kapp_slug   = query["kapp_slug"]
  form_slug   = query["form_slug"]
                # set limit at 1000
  limit       = 1000 
                # Parameters must include details, orderBy, direction, and limit. Other includes and parmeters may be added.
  params      = {"include"=>"details", "orderBy"=>"createdAt", "direction"=>"ASC", "limit" => limit}
                # Append createdAt to the Parameters if passed to method. (used by recursion to get next chunk/page)
                # Note: >= is used in order to account for possible submissions made at the same time. Therefore duplicate entries will also be found. Below duplicates are scrubbed.
  params["q"] = "createdAt>=\"#{query["start_date"]}\"" if query["start_date"]

  # Perform the query
  response = CORE_SDK.find_form_submissions(kapp_slug, form_slug, params)
  # Extract the submissions from the response
  submissions = response.content['submissions']
  puts submissions.length
  puts limit

  # If more submissions are found perform another query Else return to end queries
  if submissions.length <= limit
    # Append the last/greated createdAt date as a starting date for the next query
    query["start_date"] = (submissions.last)["createdAt"]
    # Recursively run the query
    get_submissions(query)
  else
    # No more entries found return the submissions ensuring only unique submissions are included
    return COMBINED_SUBMISSIONS.uniq!{|submission| [submission["id"]]}
  end

end


# Method to return count of all submissions for a given kapp form
def get_kapp_form_submissions(kapp_slug, form_slug)
  get_submissions({"kapp_slug" => kapp_slug, "form_slug" => form_slug})
end

# Method to return count of all submissions for a given datastore form
def get_datastore_form_submissions(form_slug)
  get_submissions({"datastore" => true, "form_slug" => form_slug})
end

# Method to return count of all submissions for a given datastore form
def get_all_datastore_form_submissions
  form_slugs = CORE_SDK.find_datastore_forms().content["forms"].map { |form| form["slug"]}
  form_slugs.each do |form_slug|
    get_datastore_form_submissions(form_slug)
  end
end

# Method to return count of all submissions in a given kapp
def get_single_kapp_submissions(kapp_slug)
  form_slugs = CORE_SDK.find_forms(kapp_slug).content["forms"].map { |form| form["slug"]}
  form_slugs.each do |form_slug|
    get_submissions({"kapp_slug" => kapp_slug, "form_slug" => form_slug})
  end
end

# method to return all submissions regardless of kapp
def get_all_kapp_submissions()
  kapp_slugs = CORE_SDK.find_kapps().content["kapps"].map { |kapp| kapp["slug"]}
  kapp_slugs.each do |kapp_slug|
    get_single_kapp_submissions(kapp_slug)
  end
end

# Determine What to Count and call the appropriate method
if KAPP_SLUG && !FORM_SLUG
  LOGGER.info "Counting all #{KAPP_SLUG} kapp submissions"
  get_single_kapp_submissions(KAPP_SLUG)
elsif KAPP_SLUG && FORM_SLUG 
  LOGGER.info "Counting all #{FORM_SLUG} submissions in the #{KAPP_SLUG} kapp"
  get_kapp_form_submissions(KAPP_SLUG, FORM_SLUG)
elsif DATASTORE && !FORM_SLUG
  LOGGER.info "Counting all datastore submissions"
  get_all_datastore_form_submissions()
elsif DATASTORE && FORM_SLUG
  LOGGER.info "Counting all #{FORM_SLUG} datastore submissions"
  get_datastore_form_submissions(FORM_SLUG)
else
  LOGGER.info "Counting all submissions in the system"
  get_all_kapp_submissions()
  get_all_datastore_form_submissions()
end

puts "Results: #{COMBINED_SUBMISSIONS}"
puts "Results: #{COMBINED_SUBMISSIONS.length}"
