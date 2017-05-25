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
    [securestring]$APIKey,
    #The body with the AI Annotation detals
    [string]$bodyJson
)	

    $retries = 1
    $success = $false

    #Send the APIKey in the header for the webrequest 
    $headers= @{ "X-AIAPIKEY" = $apiKey}

    #Find the AI Service URL URL 
    $AIServiceUrl = GetRequestUrlFromFwLink("http://go.microsoft.com/fwlink/?prd=11901&pver=1.0&sbp=Application%20Insights&plcid=0x409&clcid=0x409&ar=Annotations&sar=Create%20Annotation")
    if ($AIServiceUrl -eq $null) {
        Throw "Failed to find the redirect link to create a release annotation"
    } # Or just assume : "https://aigs1.aisvc.visualstudio.com"


    while (!$success -and $retries -lt 6) {

        $location = "$AIServiceUrl/applications/$applicationId/Annotations?api-version=2015-11"
        Write-Verbose "Create Annotation using : $location" -Verbose

        $Local:createResultStatus = $null
        $Local:createResultStatusDescription = $null
        $Local:result = $null
		#try to create the Annotation 
        try {
            $result = Invoke-WebRequest -Uri $location -Method Put -Body $bodyJson -Headers $headers `
										-ContentType "application/json; charset=utf-8" -UseBasicParsing
        } catch {
            #if an error occurred, capture the cause 
			if ($_.Exception) {
               
				if ($_.Exception.Response) {
                    $ResultStatus = $_.Exception.Response.StatusCode.value__
                    $ResultStatusDescription = $_.Exception.Response.StatusDescription
                }
                else {
                    $ResultStatus = "Exception"
                    $ResultStatusDescription = $_.Exception.Message
                }
            }
        }

        if ($result)  {
			#Success 
            $success = $true			         
        }
		else {
			#call was not succesfull, make sure there is a status to report  
            if ($ResultStatus -eq $null) {
                $ResultStatus = "Unknown"
            }
            if ($ResultStatusDescription -eq $null) {
                $ResultStatusDescription = "Unknown"
            }

			#Check if the error was a permanent error type based on the result code, 
			# # and break out of the waitloop when : conflict or unauthorized or not found 
			if ($ResultStatus -eq 409 -or $ResultStatus -eq 404 -or $ResultStatus -eq 401) { 
				break
			}
			#Wait some time and try once more 
			$retries = $retries + 1
            Write-Verbose "waiting to retry: $retries" -Verbose            
			Start-Sleep -Milliseconds 500
        }
    }
    #Return array of resutls, caller must expext this  
    return $ResultStatus, $ResultStatusDescription
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
    $Now = Get-Date
    $annotationDate = $Now.ToString("MMddyyyy_HHmmss") 

    #Input validation 
    # input must be between NOW and 90 days back maximum
    if ($eventDateTime -lt $Now.AddDays(-90) -Or $eventDateTime -gt $Now) {
        throw 'eventDateTime value must be between NOW and 90 days back maximum'
    }

    #$currentTime = (Get-Date).ToUniversalTime()
    #$annotationDate = $currentTime.ToString("MMddyyyy_HHmmss")
    #set-variable -Name requestBody -Force -Scope Script

    #No Splatting yet ...
    #Start with an empty hashtable
    $requestBody = @{}
    $requestBody.Id             = [GUID]::NewGuid()
    $requestBody.AnnotationName = $releaseName
    $requestBody.EventTime      = $eventDateTime.ToString("s")
    $requestBody.Category       = $Category

    #Add release name to any passed in properties
    $releaseProperties.Add("ReleaseName", $releaseName)
    $requestBody.Properties     = ConvertTo-Json($releaseProperties) -Compress      #to json for nesting ( one way to do this) 
    $requestBody.RelatedAnnotation=$null

    $bodyJson = $requestBody | ConvertTo-Json


    $Result = $null
    $ResultDescription = ""
    
    $Result, $ResultDescription = CreateAnnotation -applicationId $applicationId -bodyJson $bodyJson -APIKey $apiKey
    if ($Result) {
        $output = "Failed to create an annotation with Id: {0}. Error {1}, Description: {2}." -f $requestBody.Id, $Result, $ResultDescription
        throw $output
    }

    $str = "Release annotation created. Id: {0}." -f $requestBody.Id
    Write-Host $str
} 