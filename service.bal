import ballerina/http;
import ballerina/lang.runtime;
import ballerina/log;
import ballerina/uuid;

isolated map<AuthenticationContext> userAuthContextMap = {};

isolated function pushToContext(string contextId, AuthenticationContext context) {

    lock {
        userAuthContextMap[contextId] = context;
    }
}

isolated function isContextExists(string contextId) returns boolean {

    lock {
        return userAuthContextMap.hasKey(contextId);
    }
}

isolated function popFromContext(string contextId) returns AuthenticationContext {

    lock {
        return userAuthContextMap.remove(contextId);
    }
}

service / on new http:Listener(9090) {

    resource function post start\-authentication(http:Caller caller, User user) {

        string contextId = uuid:createType1AsString();

        log:printInfo(string `${contextId}: Received authentication request for the user: ${user.id}.`);

        do {
            // Create future to authenticate user with the on prem server.
            future<error?> authStatusFuture = start authenticateUser(user.cloneReadOnly());

            // Return request received response to Asgardeo.
            check caller->respond(<http:Ok>{
                body: {
                    message: "Received",
                    contextId: contextId
                }
            });

            // Add fixed delay temporarily to simulate a delay in the on prem server.
            runtime:sleep(5);

            // Retrieve user from Asgardeo for the given user id.
            future<AsgardeoUser|error> asgardeoUserFuture = start getAsgardeoUser(user.id);

            // Wait for the response of on prem invocation.
            error? authStatus = check wait authStatusFuture;

            if authStatus is error {
                log:printInfo(string `${contextId}: Authentication failed with on prem server.`);

                if authStatus.message() == "Invalid credentials" {
                    log:printInfo(string `${contextId}: Invalid credentials provided for the user: ${user.id}.`);

                    AuthenticationContext context = {
                        username: user.username,
                        status: "FAIL",
                        message: "Invalid credentials"
                    };
                    pushToContext(contextId, context);
                } else {
                    log:printError(string `${contextId}: Error occurred while authenticating the user: ${user.id}.`, authStatus);

                    AuthenticationContext context = {
                        username: user.username,
                        status: "FAIL",
                        message: "Something went wrong"
                    };
                    pushToContext(contextId, context);
                }
            }

            log:printInfo(string `${contextId}: User authenticated with on prem server.`);

            // Wait for the response of Asgardeo invocation.
            AsgardeoUser|error asgardeoUser = check wait asgardeoUserFuture;
            log:printInfo(string `${contextId}: User retrieved from Asgardeo.`);

            if asgardeoUser is error {
                log:printInfo(string `${contextId}: Error occurred while retrieving user from Asgardeo.`, asgardeoUser);

                fail error("Something went wrong.");
            }

            // Validate the username.
            if asgardeoUser.username !== user.username {
                log:printInfo(string `${contextId}: Invalid username provided for the user: ${user.id}.`);

                fail error("Invalid credentials");
            }

            log:printInfo(string `${contextId}: Username validated successfully.`);
            log:printInfo(string `${contextId}: On prem authentication successful for the user: ${user.id}.`);

            // Add successful authentication context to the map.
            AuthenticationContext context = {
                username: user.username,
                status: "SUCCESS",
                message: "Authenticated successful"
            };
            pushToContext(contextId, context);

        } on fail error err {
            if err.message() == "Invalid credentials" {
                log:printInfo(string `${contextId}: Invalid credentials provided for the user: ${user.id}.`);

                AuthenticationContext context = {
                    username: user.username,
                    status: "FAIL",
                    message: "Invalid credentials"
                };
                pushToContext(contextId, context);
            } else {
                log:printError(string `${contextId}: Error occurred while authenticating the user: ${user.id}.`, err);

                AuthenticationContext context = {
                    username: user.username,
                    status: "FAIL",
                    message: "Something went wrong"
                };
                pushToContext(contextId, context);
            }
        }
    }

    resource function post authentication\-status(AuthenticationStatusRequest authStatus) returns http:Ok|http:BadRequest {

        string contextId = authStatus.contextId;
        string username = authStatus.username;

        log:printInfo(string `Received authentication status check for the context id: ${contextId}.`);

        if (isContextExists(contextId)) {
            AuthenticationContext? context = popFromContext(contextId);

            if (context == null) {
                log:printInfo(string `${contextId}: Error occurred while retrieving the authentication status. Context not found.`);

                return <http:BadRequest>{
                    body: {
                        message: "Invalid context id"
                    }
                };
            }

            log:printInfo(string `${contextId}: Authentication status retrieved successfully.`);

            if (context.username == username) {
                log:printInfo(string `${contextId}: Username validated successfully.`);

                return <http:Ok>{
                    body: {
                        status: context.status,
                        message: context.message
                    }
                };
            } else {
                log:printInfo(string `${contextId}: Provided username does NOT match with the context username.`);

                return <http:Ok>{
                    body: {
                        status: "FAIL",
                        message: "Invalid request"
                    }
                };
            }
        } else {
            log:printInfo(string `Authentication status not found for the context id: ${contextId}.`);

            return <http:BadRequest>{
                body: {
                    message: "Invalid context id"
                }
            };
        }
    }

    resource function get authentication\-status(string contextId) returns http:Ok {

        log:printInfo(string `Received status polling query for the context id: ${contextId}.`);

        if (isContextExists(contextId)) {
            log:printInfo(string `${contextId}: Context found for the status query.`);

            return <http:Ok>{
                body: {
                    status: "COMPLETE"
                }
            };
        } else {
            log:printInfo(string `${contextId}: Context not found for the status query.`);

            return <http:Ok>{
                body: {
                    status: "PENDING"
                }
            };
        }
    }
}
