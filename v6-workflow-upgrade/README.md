# Workflow Update
This script is used to update v5 trees to v6 routines

Tree from v5 will be analyzed and updated at v6 workflows attached to either the Space, a Kapp, or a form.
- An export of all trees will be performed and can be used as a backup if necessary
- After converting an importing to a v6 workflow the tree will be deleted.
- Results will be output to the output.log file

What will be converted
- Source Name:
    Only trees in the Kinetic Request CE datasource will be migrated to workflow
- Source Group
    Only trees starting with the the following Source Groups will be converted:
    - "Datastore Submissions"
    - "Datastore Forms"
    - "Forms"
    - "Submissions"
    - "Teams"
    - "Users"
- Name
    Only trees with the following Name will be converted
    - "Closed"
    - "Created"
    - "Deleted"
    - "Saved"
    - "Submitted"
    - "Updated"
- Anything not matching the above would not be triggered by the v6 Task Engine w/o a Web API. It will be left as is for the developer to decided how it should be addressed.

## Instructions
1. Create a copy of the config-sample.yaml file and naming it config.yaml. Next, update the values inside this file to point to the right Kinetic Platform Environment

2. Run the workflow-update.rb file against the space you're trying to update. 

3. Check the output.log to see if there are any errors.

## Other Considerations

After running the script some Webhooks may need to be deleted and some workflows updated.
- Webhooks previously triggered workflows and also had filters
    - In most cases the webhooks will no longer be needed.
    - Trees that have been converted to Workflows will not need Webhooks. (Look at output.log for what was converted)
    - Any Workflow triggered by a Webhook with a filter defined in it may need similar logic into the workflow before after the conversion. 
        - For example the Kinops Webhook "Submission Submitted" contained the filter "form('attribute:Custom Submission Workflow').indexOf('Submitted') === -1". This filter only fired the Webhook if the request was not defined to run a custom workflow. This condition must now be put into the workflow. The tree will still trigger but the condition should prevent it from continuing when appropriate.
- Some Webhooks may need to stay. As an example the "Kapp Submissions Reporting/Upsert" tree is trigger by 3 individual webhooks and the three webhooks should stay. The tree remains unconverted.
- The webhooks will need to be analyzed for each client to determine the correct course of action

