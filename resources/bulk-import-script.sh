#!/bin/bash

# Configurable variables
FILE_PATH="path/to/csv_file.csv"
SERVER_BASE_URL="api.asgardeo.io/t/<your_organization>"
ACCESS_TOKEN="<your_token>"

# Function to execute SCIM API call for each user.
function invoke_scim_api {

    local givenName="$1"
    local familyName="$2"
    local userName="$3"
    local email="$4"
    local phoneNumber="$5"
    local profileUrl="$6"

    echo "Migrating the user: $userName"
    echo ""

    if [[ -z $givenName || -z $familyName || -z $email || -z $userName ]]; then
        echo "Skipping migration for the user: $userName. Required fields are missing."
        return
    fi

    payload='{
        "name": {
            "givenName": "'"$givenName"'",
            "familyName": "'"$familyName"'"
        },
        "userName": "DEFAULT/'"$userName"'",
        "password": "b0F0DgdorACH5l7",
        "emails": [
            {
                "value": "'"$email"'",
                "primary": true
            }
        ]'

    if [[ -n $phoneNumber ]]; then
        payload+=',
        "phoneNumbers": [
            {
                "type": "mobile",
                "value": '$phoneNumber'
            }
        ]'
    fi

    if [[ -n $profileUrl ]]; then
        payload+=',
        "profileUrl": '$profileUrl''
    fi

    payload+='
    }'

    curl --location -k "https://$SERVER_BASE_URL/scim2/Users" \
    --header 'Accept: application/scim+json' \
    --header 'Content-Type: application/scim+json' \
    --header "Authorization: Bearer $ACCESS_TOKEN" \
    --data-raw "$payload"

    echo ""
    echo "User migration completed."
    echo ""
}

echo "Starting the user migration process..."
echo ""

# Read the CSV file line by line
while IFS=',' read -r id userName email profileUrl givenName familyName phoneNumber ; do
    # Skip the header line.
    if [[ $id == "id" ]]; then
        continue
    fi

    # Execute API call for each entry.
    invoke_scim_api "$givenName" "$familyName" "$email" "$email" "$phoneNumber" "$profileUrl"
done < "$FILE_PATH"

echo "User migration process completed."
