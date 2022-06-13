# Find User in Spaces

This script is used to to interact with the SYSTEM (ie not space) API to find which spaces a user exists in.

## Instructions

1. Run `bundle install` to ensure the required gems are installed.
2. Copy `config-sample.yaml` file to `config.yaml` and update the values to point to your Kinetic Platform environment.
3. Run the [find-user-in-spaces.rb](find-user-in-spaces.rb) script, passing in the user that you want to find. The output will be written into the log file. Pass --remove true if you would like the user to be removed.

```sh
ruby find-user-in-spaces.rb --user jdoe@example.com
```

> The script searchs for the user by both username, displayName and email using the provided user string
