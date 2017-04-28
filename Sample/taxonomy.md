
#User Context
-----
User.Id
Anonymous user id. 
Represents the end user of the application. 
When telemetry is sent from a service, the user context is about the user that initiated the operation in the service.
UserId = "ai.user.id";

    
User.AuthUserId
Authenticated user id. 
The opposite of ai.user.id, this represents the user with a friendly name. 
Since it's PII information it is not collected by default by most SDKs.
UserAuthUserId = "ai.user.authUserId";


#Application Context
------------
Application.Version
Application version. 
Information in the application context fields is always about the application that is sending the telemetry.")]
ApplicationVersion = "ai.application.ver";



#Operation Context 
----------
Only on RequestTelemetry and DepedencyTelemetry

.ID
A unique identifier for the operation instance. The operation.id is created by either a request or a page view. 
All other telemetry sets this to the value for the containing request or page view. 
Operation.id is used for finding all the telemetry items for a specific operation instance.
OperationId = "ai.operation.id";
    
.Name
The name (group) of the operation. 
The operation.name is created by either a request or a page view. 
All other telemetry items set this to the value for the containing request or page view. 
Operation.name is used for finding all the telemetry items for a group of operations (i.e. 'GET Home/Index').
OperationName = "ai.operation.name";
   

.OperationParentId
The unique identifier of the telemetry item`s immediate parent.
OperationParentId = "ai.operation.parentId";
    
.OperationSyntheticSource
Name of synthetic source. 
Some telemetry from the application may represent a synthetic traffic. 
It may be web crawler indexing the web site, site availability tests or traces from diagnostic libraries or tests 

OperationSyntheticSource = "ai.operation.syntheticSource";

.OperationCorrelationVector
The correlation vector is a light weight vector clock which can be used to identify and order related events across clients and services.
OperationCorrelationVector = "ai.operation.correlationVector";



    