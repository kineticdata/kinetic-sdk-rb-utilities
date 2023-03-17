# Import Users
This script is used to import users from a CSV file

## Instructions
1. Create a copy of the config-sample.yaml file and naming it config.yaml. Next, update the values inside this file to point to the right Kinetic Platform Environment

2. Add the CSV of users you'd like to import inside the `./data` directory and name the file `users.csv`

3. Update the [import-users.rb](import-users.rb) script and find the  to map the CSV header values to a valid Kinetic Platform User property. 

For Example:

```ruby
    # Create a map of applicable attributes
    attributesMap = {
      "Manager" => ["#{row["Manager"]}"]
    }

    profileAttributesMap = {
      "Phone Number" => ["#{row["Phone Number"]}"]
    }

    # Build up user object
    user = {
        "username"              => row["User ID"],
        "displayName"           => row["Name"],
        "email"                 => row["Email Address"],
        "attributesMap"         => attributesMap,
        "profileAttributesMap"  => profileAttributesMap,
        "spaceAdmin"            => row["Is Admin"].downcase == "true" ? true : false,
    }

```
