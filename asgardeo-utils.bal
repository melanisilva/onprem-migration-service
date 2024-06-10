import ballerina/http;
import ballerina/log;
import ballerina/regex;

// Configurable parameters.
configurable string asgardeoUrl = ?;
configurable AsgardeoAppConfig asgardeoAppConfig = ?;

// Asgardeo scopes to invoke the APIs.
final string asgardeoScopes = "internal_user_mgt_view";

final http:Client asgardeoClient = check new (asgardeoUrl, {
    auth: {
        ...asgardeoAppConfig,
        scopes: asgardeoScopes
    }
});

# Retrieve the given user from Asgardeo.
# 
# + id - The id of the user.
# + return - The AsgardeoUser if the user is found, else an error.
isolated function getAsgardeoUser(string id) returns AsgardeoUser|error {

    // Retrieve user from the Asgardeo server given the user id.
    json|error jsonResponse = asgardeoClient->get("/scim2/Users/" + id);

    // Handle error response.
    if jsonResponse is error {
        log:printError(string `Error while fetching Asgardeo user for the id: ${id}.`, jsonResponse);
        return error("Error while fetching the user.");
    }

    AsgardeoUserResponse response = check jsonResponse.cloneWithType(AsgardeoUserResponse);

    if response.userName == "" {
        log:printError(string `A user not found for the id: ${id}.`);
        return error("User not found.");
    }

    // Extract the username from the response.
    string username = regex:split(response.userName, "/")[1];

    log:printInfo("Successfully retrieved the username from Asgardeo.");

    // Return the user object.
    return {
        id: response.id,
        username: username
    };
}
