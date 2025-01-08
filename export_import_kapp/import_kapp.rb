require "kinetic_sdk"

# find the directory of this script
platform_template_path = File.dirname(File.expand_path(__FILE__))
core_path = File.join(platform_template_path, "core")

# load the space_sdkection configuration file
begin
  config = YAML.load_file( File.join(platform_template_path, "config.yaml") )
rescue
  raise StandardError.new "There was a problem loading the config.yaml file"
end

# Create space space_sdkection
space_sdk = KineticSdk::Core.new({
  space_server_url: config["SERVER_URL"],
  space_slug: config["SPACE_SLUG"],
  username: config["SPACE_USERNAME"],
  password: config["SPACE_PASSWORD"],
  options: {
    log_level: config["LOG_LEVEL"],
  }
})

params = {
  "include"=>config["INCLUDE"],
}

kapp_dirs = Dir["#{platform_template_path}/core/space/kapps/*"].select { |fn| File.directory?(fn) }
kapp_dirs.each { |file|   
  #Add or Update the Kapp
  if File.file?(file) or ( File.directory?(file) and File.file?(file = "#{file}.json") ) # If the file is a file or a dir with a corresponding json file
    kapp = JSON.parse( File.read(file) )
    kappExists = space_sdk.find_kapp(kapp['slug']).code.to_i == 200  
    if kappExists
      space_sdk.update_kapp(kapp['slug'], kapp)
    else
      space_sdk.add_kapp(kapp['name'], kapp['slug'], kapp)
    end
  end 
  kapp_slug = kapp['slug']

  # ------------------------------------------------------------------------------
  # Migrate Kapp Attribute Definitions
  # ------------------------------------------------------------------------------
  if File.file?(file = "#{core_path}/space/kapps/#{kapp['slug']}/kappAttributeDefinitions.json")
    destinationKappAttributeArray = (space_sdk.find_kapp_attribute_definitions(kapp['slug']).content['kappAttributeDefinitions'] || {}).map { |definition|  definition['name']}
    kappAttributeDefinitions = JSON.parse(File.read(file))
    (kappAttributeDefinitions || []).each { |attribute|
        if destinationKappAttributeArray.include?(attribute['name'])
          space_sdk.update_kapp_attribute_definition(kapp['slug'], attribute['name'], attribute)
        else
          space_sdk.add_kapp_attribute_definition(kapp['slug'], attribute['name'], attribute['description'], attribute['allowsMultiple'])
        end
    }   
  end

  # ------------------------------------------------------------------------------
  # Migrate Kapp Category Definitions
  # ------------------------------------------------------------------------------
  if File.file?(file = "#{core_path}/space/kapps/#{kapp['slug']}/categoryAttributeDefinitions.json")
    destinationKappAttributeArray = (space_sdk.find_category_attribute_definitions(kapp['slug']).content['categoryAttributeDefinitions'] || {}).map { |definition|  definition['name']}  
    kappCategoryDefinitions = JSON.parse(File.read(file))
    (kappCategoryDefinitions || []).each { |attribute|
        if destinationKappAttributeArray.include?(attribute['name'])
          space_sdk.update_category_attribute_definition(kapp['slug'], attribute['name'], attribute)
        else
          space_sdk.add_category_attribute_definition(kapp['slug'], attribute['name'], attribute['description'], attribute['allowsMultiple'])
        end
    }   
  end
  
  # ------------------------------------------------------------------------------
  # Migrate Kapp Form Attribute Definitions
  # ------------------------------------------------------------------------------
  if File.file?(file = "#{core_path}/space/kapps/#{kapp['slug']}/formAttributeDefinitions.json")
    destinationFormAttributeArray = (space_sdk.find_form_attribute_definitions(kapp['slug']).content['formAttributeDefinitions'] || {}).map { |definition|  definition['name']}
    formAttributeDefinitions = JSON.parse(File.read(file))
    (formAttributeDefinitions || []).each { |attribute|
        if destinationFormAttributeArray.include?(attribute['name'])
          space_sdk.update_form_attribute_definition(kapp['slug'], attribute['name'], attribute)
        else
          space_sdk.add_form_attribute_definition(kapp['slug'], attribute['name'], attribute['description'], attribute['allowsMultiple'])
        end
    }   
  end
  
  # ------------------------------------------------------------------------------
  # Migrate Kapp Form Type Definitions
  # ------------------------------------------------------------------------------
  if File.file?(file = "#{core_path}/space/kapps/#{kapp['slug']}/formTypes.json")
    destinationFormTypesArray = (space_sdk.find_formtypes(kapp['slug']).content['formTypes'] || {}).map { |formTypes|  formTypes['name']}
    formTypes = JSON.parse(File.read(file))
    (formTypes || []).each { |body|
      if destinationFormTypesArray.include?(body['name'])
        space_sdk.update_formtype(kapp['slug'], body['name'], body)
      else
        space_sdk.add_formtype(kapp['slug'], body)
      end
    }
  end

  # ------------------------------------------------------------------------------
  # Migrate Kapp Security Policy Definitions
  # ------------------------------------------------------------------------------
  if File.file?(file = "#{core_path}/space/kapps/#{kapp['slug']}/securityPolicyDefinitions.json")
    destinationSecurtyPolicyArray = (space_sdk.find_security_policy_definitions(kapp['slug']).content['securityPolicyDefinitions'] || {}).map { |definition|  definition['name']}
    securityPolicyDefinitions = JSON.parse(File.read(file))
    (securityPolicyDefinitions || []).each { |attribute|
        if destinationSecurtyPolicyArray.include?(attribute['name'])
          space_sdk.update_security_policy_definition(kapp['slug'], attribute['name'], attribute)
        else
          space_sdk.add_security_policy_definition(kapp['slug'], attribute)
        end
    }   
  end
  
  # ------------------------------------------------------------------------------
  # Migrate Kapp Categories
  # ------------------------------------------------------------------------------
  if File.file?(file = "#{core_path}/space/kapps/#{kapp['slug']}/categories.json")
    destinationCategoryArray = (space_sdk.find_categories(kapp['slug']).content['categories'] || {}).map { |definition|  definition['slug']}
    categories = JSON.parse(File.read(file))
    (categories || []).each { |attribute|
      if destinationCategoryArray.include?(attribute['slug'])
        space_sdk.update_category_on_kapp(kapp['slug'], attribute['slug'], attribute)
      else
        space_sdk.add_category_on_kapp(kapp['slug'], attribute)
      end
    }
  end

  # ------------------------------------------------------------------------------
  # Migrate Kapp Webhooks
  # ------------------------------------------------------------------------------
  webhooks_on_kapp = space_sdk.find_webhooks_on_kapp(kapp['slug']) 
  if webhooks_on_kapp.code=="200" 
    destinationWebhookArray = (webhooks_on_kapp.content['webhooks'] || {}).map { |definition|  definition['name']}
    Dir["#{core_path}/space/kapps/#{kapp['slug']}/webhooks/*.json"].each{ |webhookFile|
        webhookDef = JSON.parse(File.read(webhookFile))
        if destinationWebhookArray.include?(webhookDef['name'])
          space_sdk.update_webhook_on_kapp(kapp['slug'], webhookDef['name'], webhookDef)
        else
          space_sdk.add_webhook_on_kapp(kapp['slug'], webhookDef)
        end
    }   
  end  

  # ------------------------------------------------------------------------------
  # Add Kapp Forms
  # ------------------------------------------------------------------------------
  if (forms = Dir["#{platform_template_path}/core/space/kapps/#{kapp_slug}/forms/*.json"]).length > 0 
    destinationForms = (space_sdk.find_forms(kapp_slug).content['forms'] || {}).map{ |form| form['slug']}
    forms.each { |form|
      properties = File.read(form)
      form = JSON.parse(properties)
      if destinationForms.include?(form['slug'])
        space_sdk.update_form(kapp_slug ,form['slug'], form)
      else   
        space_sdk.add_form(kapp_slug, form)
      end
    }
  end
}