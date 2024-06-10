type User record {|
    readonly string id;
    readonly string username;
    readonly string password;
|};

type AsgardeoUser record {|
    string id;
    string username;
|};

type AsgardeoAppConfig readonly & record {|
    string tokenUrl;
    string clientId;
    string clientSecret;
|};

type AsgardeoUserResponse record {|
    string id;
    string userName;
    string[] emails;
    json...;
|};

type AuthenticationContext record {|
    readonly string username;
    readonly string status;
    readonly string message?;
|};

type AuthenticationStatusRequest record {|
    readonly string contextId;
    readonly string username;
|};
