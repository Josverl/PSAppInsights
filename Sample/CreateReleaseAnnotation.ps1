# Sample usage .\CreateReleaseAnnotation.ps1 -applicationId "<appId>" -apiKey "<apiKey>" -releaseName "<releaseName>" -releaseProperties @{"ReleaseDescription"="Release with annotation";"TriggerBy"="John Doe"} -eventDateTime "2016-07-07T06:23:44"

#Requires -version 3

function GetRequestUrlFromFwLink($fwLink) {
    # background info on how fwlink works: After you submit a web request, many sites redirect through a series of intermediate pages before you finally land on the destination page.
    # So when calling Invoke-WebRequest, the result it returns comes from the final page in any redirect sequence. Hence, I set MaximumRedirection to 0, as this prevents the call to 
    # be redirected. By doing this, we get a resposne with status code 302, which indicates that there is a redirection link from the response body. We grab this redirection link and 
    # construct the url to make a release annotation.
    # Here's how this logic is going to works
    # 1. Client send http request, such as:  http://go.microsoft.com/fwlink/?LinkId=625115
    # 2. FWLink get the request and find out the destination URL for it, such as:  http://www.bing.com
    # 3. FWLink generate a new http response with status code “302” and with destination URL “http://www.bing.com”. Send it back to Client.
    # 4. Client, such as a powershell script, knows that status code “302” means redirection to new a location, and the target location is “http://www.bing.com”
	
    $request = Invoke-WebRequest -Uri $fwLink -MaximumRedirection 0 -UseBasicParsing -ErrorAction Ignore
    if ($request.StatusCode -eq "302") {
        #Return the(first) redirect URL 
        return $request.Headers.Location
    }
    return $null
}

#
function CreateAnnotation {
[CmdletBinding()]
Param (
    #The AI Application ID (not the iKey)        
    [string]$applicationId,
    #An API Key to th AI Application 
    [string]$APIKey,
    #The body with the AI Annotation detals
    [string]$bodyJson
)	
    #Initialize 
    $retries = 1
    $success = $false

    #Send the APIKey in the header for the webrequest 
    $headers= @{ "X-AIAPIKEY" = $apiKey}

    #Find the AI Service URL URL 
    $AIServiceUrl = GetRequestUrlFromFwLink("http://go.microsoft.com/fwlink/?prd=11901&pver=1.0&sbp=Application%20Insights&plcid=0x409&clcid=0x409&ar=Annotations&sar=Create%20Annotation")
    if ($AIServiceUrl -eq $null) {
        Throw "Failed to find the redirect link to create a release annotation"
    } # Or just assume : "https://aigs1.aisvc.visualstudio.com"

    #Process
    while (!$success -and $retries -lt 6) {

        $location = "$AIServiceUrl/applications/$applicationId/Annotations?api-version=2015-11"
        Write-Verbose "Create Annotation using : $location" 

        $ErrorStatus = $null
        $ErrorStatusDescription = $null
        $result = $null
		#try to create the Annotation 
        try {
            $result = Invoke-WebRequest -Uri $location -Method Put -Body $bodyJson -Headers $headers `
										-ContentType "application/json; charset=utf-8" -UseBasicParsing
        } catch {
            #Construct error message 
            if ($_.Exception.Response) {

                $ErrorStatus = $_.Exception.Response.StatusCode.value__
                $ErrorStatusDescription = $_.Exception.Response.StatusDescription
            }
            else {
                $ErrorStatus = "Exception"
                $ErrorStatusDescription = $_.Exception.Message
            }            
            $Message = "Failed to create an annotation. Error {1}, Description: {2}." -f  $Result, $ResultDescription
            Throw $Message
        }

        if ($result.StatusCode -eq 200)  {
			#Response indicates Success 
            $success = $true
            return $result
            break   
        }
		#Check if the error was a permanent error type based on the result code, 
	    # and break out of the waitloop when : conflict or unauthorized or not found 
        if ($result.StatusCode -in 409,404,401) {
            $Message = "Failed to create an annotation. Error {1}, Description: {2}." -f  $Result.StatusCode, $Result.StatusDescription
            Throw $Message
        }   
        $retries = $retries + 1
        Write-Verbose "waiting to retry: $retries"            
        Start-Sleep -Milliseconds 500
    }
    #After 6 tries , stop trying
    $Message = "Timeout while attempting to create an annotation. LastError {1}, Description: {2}." -f  $Result.StatusCode, $Result.StatusDescription
    throw $Message
}


Function CreateReleaseAnnotation { 
    param(
        [parameter(Mandatory = $true)]
		[string]$applicationId,
        [parameter(Mandatory = $true)]
		[string]$apiKey,

        [parameter(Mandatory = $true)]
		[string]$releaseName,
        #A hashtable of additional properties to associate with the Release  
        [parameter(Mandatory = $false)]
		[Hashtable]$releaseProperties = @{},

        #Event date/time , defaults to current time 
        [parameter(Mandatory = $false)]
		[DateTime]$eventDateTime = (Get-Date ),

        #The Annotation's category, default = 'Deployment'
        [string]$Category = 'Deployment'
    )
    #Input validation 
    # input must be between NOW and 90 days back maximum
    $Now = Get-Date
    if ($eventDateTime -lt $Now.AddDays(-90) -Or $eventDateTime -gt $Now) {
        throw 'eventDateTime value must be between NOW and 90 days back maximum'
    }

    #Start with an empty hashtable
    $requestBody = @{}
    $requestBody.Id             = [GUID]::NewGuid()
    $requestBody.AnnotationName = $releaseName
    $requestBody.EventTime      = $eventDateTime.ToString("s")
    $requestBody.Category       = $Category

    #Add release name to any passed in properties
    $releaseProperties.Add("ReleaseName", $releaseName)
    $requestBody.Properties     = ConvertTo-Json($releaseProperties) -Compress      #to json for nesting
    $requestBody.RelatedAnnotation=$null
    #Convert the information to a json document 
    $bodyJson = $requestBody | ConvertTo-Json -Compress                             #includes nested json 

    $Result = $null
  
    $Result = createAnnotation -applicationId $applicationId -bodyJson $bodyJson -APIKey $apiKey
    if ($Result) {
        $ReleaseInfo = $result.Content | Convertfrom-json
        $Message = "Release annotation created. Id: {0}." -f $requestBody.Id
        Write-Verbose $Message
    }
} 