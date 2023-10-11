# Remove Discussions
This script is used to update v5 trees to v6 routines

Tree from v5 will be anyalized and updated at v6 workflows attached to eihter the Space, a Kapp, or a form.
- An export of all trees will be performed and can be used as a backup if necessary
- After converting an importing to a v6 workflow the tree will be deleted.
- Only tree in the Kinetic Request CE datasource will be migrated to workflow
- Results will be output to the output.log file

## Instructions
1. Create a copy of the config-sample.yaml file and naming it config.yaml. Next, update the values inside this file to point to the right Kinetic Platform Environment

2. Run the workflow-update.rb file against the space you're trying to update. 

3. Check the output.log to see if there are any errors.