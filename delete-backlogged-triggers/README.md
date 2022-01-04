# Update Kapp Form Fields

This script is used to update fields in all forms of the specified kapp.

## Instructions

1. Run `bundle install` to ensure the required gems are installed.
2. Copy `config-sample.yaml` file to `config.yaml` and update the values to point to your Kinetic Platform environment.
3. Check the `fields.yaml` file and update the field names and properties to your specifications.
4. Run the [update-kapp-form-fields.rb](update-kapp-form-fields.rb) script, passing in the kapp slug in which to update.

```sh
ruby update-kapp-form-fields.rb --kapp services
```
