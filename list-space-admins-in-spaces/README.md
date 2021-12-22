# List Space Admins In Spaces

This script is used to to interact with the SYSTEM (ie not space) API to get a complete list of spaces and their associated spaceAdmins. 

## Instructions

1. Run `bundle install` to ensure the required gems are installed.
2. Copy `config-sample.yaml` file to `config.yaml` and update the values to point to your Kinetic Platform environment.
4. Run the [list-space-admins-in-spaces.rb](list-space-admins-in-spaces.rb) script.
The output will be written into an `output.csv` file.

```sh
ruby list-space-admins-in-spaces.rb
```