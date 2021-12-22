# Get Submission Counts

This script uses the Kinetic Platform API to retrieve a list of submissions and outputs them to a file called `output.csv`

## Instructions

1. cd into this directory (get-submission-counts) and run `bundle install` to install the required dependencies.

2. Create a copy of the config-sample.yaml file and naming it config.yaml. Next, update the values inside this file to point to the right Kinetic Platform Environment

3. Run the `get-submission-counts.rb` file using the following optional parameters

- kapp (optional) - If you would like to scope the submission counts to a specific kapp
- form (optional) - If you would like to scope the submission counts to a specific form. Kapp slug or datastore flag required
- datastore (optional) - If this flag is provided with no `-form` option, the script will only count datastore forms. If a form is provided via the `-form` flag it will only provide counts for a specific form

4. Open the `output.csv` file to analize the results

## Modifications

Feel free to modify this script as needed to provide more parameters or critera for searching submissions. More information on how to query the Kinetic Platform API via the SDK can be found here: https://github.com/kineticdata/kinetic-sdk-rb/blob/master/lib/kinetic_sdk/core/lib/submissions.rb
