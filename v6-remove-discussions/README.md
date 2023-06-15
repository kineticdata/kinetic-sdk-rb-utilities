# Remove Discussions
This script is used to check if spaces can be safely upgraded to v6 and if so, remove upgrades.

## Instructions
1. Create a copy of the config-sample.yaml file and naming it config.yaml. Next, update the values inside this file to point to the right Kinetic Platform Environment

2. Run the preflight-check.rb file against the space you're trying to migrate. It will DOES NOT modify any data `ruby preflight-check`

3. Check the output.log to see if there are any warnings about migrating.
    - If a tree/routine has the message "does not match original" it *may* mean that the workflow was modified/customized. If the remove-discussions.rb script is run it will overwrite the customizations.
    - If a tree/routine has the message "NOT FOUND:", the workflow was not found. The remove-discussions.rb script will not find or update this workflow.

4. If no warnings and you've tested against a non-production environment, run `ruby remove-discussions.rb` to migrate the workflow changes and remove the objects that are no longer needed.

5. After the `remove-discussions.rb` script is run, an export of the system should be performed and the output examined for any ocurrance of "discussion". Look for any of the following:

    Forms:
    - Many forms will still have "discussion" in the definition. The field "Discussion Id" and an idex for it exists in many forms. Removing these is unecessary and tedious. These references may stay for now.

    Workflow 
    Some additional workflow still has discussion in it and can be included in this script and updated. The history and modification can be found it Git at: https://github.com/kineticdata/platform-template-service-portal
        - admin-kapp-submission-config
        - handler-failure-error-process
        - queue-task-create
        - service-portal-submission-config


    Addtional elements that may include the use of discussions.   
    - Models using discussions


    