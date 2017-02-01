<#

// Establish an operation context and associated telemetry item:
using (var operation = telemetry.StartOperation<RequestTelemetry>("operationName"))
{
    // Telemetry sent in here will use the same operation ID.
    ...
    telemetry.TrackEvent(...); // or other Track* calls
    ...
    // Set properties of containing telemetry item - for example:
    operation.Telemetry.ResponseCode = "200";

    // Optional: explicitly send telemetry item:
    telemetry.StopOperation(operation);

} // When operation is disposed, telemetry item is sent.

#>


#ToDo - Seperate this to Start-AIOperation 
            if ($Initializer.Contains('Operation')) {
                #Initializer for operation correlation 
                $OpInit = [Microsoft.ApplicationInsights.Extensibility.OperationCorrelationTelemetryInitializer]::new()
                $Global:AISingleton.Configuration.TelemetryInitializers.Add($OpInit)
            }



[Microsoft.ApplicationInsights.Extensibility.Implementation.OperationContext]

[Microsoft.ApplicationInsights.Extensibility.Implementation.OperationTelemetry]
new-object 'Microsoft.ApplicationInsights.Extensibility.Implementation.OperationTelemetry'

[Microsoft.ApplicationInsights.OperationTelemetryExtensions]::Start( $OperationTelemetry) 
[Microsoft.ApplicationInsights.OperationTelemetryExtensions]::Stop
[Microsoft.ApplicationInsights.OperationTelemetryExtensions]::GenerateOperationId


[Microsoft.ApplicationInsights.OperationTelemetryExtensions]::Start.OverloadDefinitions
# static void Start(Microsoft.ApplicationInsights.Extensibility.Implementation.OperationTelemetry telemetry)

[Microsoft.ApplicationInsights.OperationTelemetryExtensions]::Stop.OverloadDefinitions
[Microsoft.ApplicationInsights.OperationTelemetryExtensions]::GenerateOperationId.OverloadDefinitions
