# Remove Discussions
This script is used to check if spaces can be safely upgraded to v6 and if so, remove upgrades.

## Instructions
1. Create a copy of the config-sample.yaml file and naming it config.yaml. Next, update the values inside this file to point to the right Kinetic Platform Environment

2. Run the preflight-check.rb file against the space you're trying to migrate. It will DOES NOT modify any data `ruby preflight-check`

3. Check the output.log to see if there are any warnings about migrating.

4. If no warnings and you've tested against a non-production environment, run `ruby remove-discussions.rb` to migrate the workflow changes and remove the objects that are no longer needed.
