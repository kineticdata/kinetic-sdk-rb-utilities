require "kinetic_sdk"
#require "optparse"
#require "teelogger"
require 'logger'

logger = Logger.new(STDERR)
logger.level = Logger::INFO
logger.formatter = proc do |severity, datetime, progname, msg|
  date_format = datetime.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
  "[#{date_format}] #{severity}: #{msg}\n"
end


# find the directory of this script
PWD = File.expand_path(File.dirname(__FILE__))

logger.info "#{PWD}/core/space/kapps/"

events_to_remove = ["Render Requested For Widget", "Render Contact Widget", "Load Additional Requested For Table", "Render Additional Requested For Widget", "Load Standard People Widgets And Table"]

events_to_add = [
  {
    "name": "Load Standard People Widgets And Table",
    "type": "Load",
    "action": "Custom",
    "code": "//Load Requested For Widget\nbundle.fn.renderReqForWidget(K('form'), identity);\n\n//Load Contact Widget\nbundle.fn.renderContactWidget(K('form'), identity);\n\n//Load Additonal Requested For Widget\nbundle.fn.renderAdditionalReqForWidget(K('form'));\n\n//Load Additional Requested For Table\nbundle.fn.loadAdditionalReqForTable(K('form'));",
    "runIf": ""
  }
]

  # ------------------------------------------------------------------------------
  # Add and Remove Page Events
  # ------------------------------------------------------------------------------

  Dir["#{PWD}/core/space/kapps/services/forms/*.json"].each { |form|
    properties = File.read(form)
    form_json = JSON.parse(properties)
    form_json['customHeadContent'] = ""
    events = form_json['pages'][0]['events']
    events.each{ |event|
      if events_to_remove.include?(event['name'])
        events.delete_if { |event| events_to_remove.include?(event['name']) }
      end
    }
    events.push(events_to_add[0])
    form_content = JSON.pretty_generate(form_json)
    File.write(form, form_content)
  }
  
