# Delete Submissions by Query

This script is used to update forms matched in a kapp, form slug, or query.

The current state of the script only "touches" the form by retrieving and updating it with the same content.  Additional code needs to be added to append, delete, or update any of the form properties.

## Instructions

1. Run `bundle install` to ensure the required gems are installed.
2. Copy `config-sample.yaml` file to `config.yaml` and update the values to point to your Kinetic Platform environment.
3. Run the [update-form.rb](delete-submissions-by-query.rb) script.

```sh
update-form.rb 
```
