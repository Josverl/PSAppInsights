<#
Test functions to capture information send to AI during testing 

Ensure-Fiddler          Makes sure Fiddler is started (It must be configured to capture non-browser or All traffic)
Start-FiddlerCapture    Clears any capture in fiddler and starts a fresh capture 
Save-FiddlerCapture     Saves all data captured from the curren Process to a JSON format (requires a FiddlerScript function to be added)
Read-FiddlerAICapture   Read and process the Capture , and processess the JSON objects in post and body support testing.

#>

function Ensure-Fiddler {
[CmdletBinding()]
[OutputType([void])]    
Param (
    [Switch]$Show
)
   
    if ($Show) { 
        $Action = "show"
    } else {
        $Action = "hide"
    }
    #Make Sure fiddler is started 
    if (-not (Get-Process -Name 'Fiddler' -ErrorAction SilentlyContinue)) { 
        Start-Process "C:\Program Files (x86)\Fiddler2\Fiddler.exe" -ArgumentList "-quit"

        #Wait for Fiddler to start 
        while(-not (Get-Process -Name 'Fiddler' -ErrorAction SilentlyContinue)) {    
            Start-Sleep -Milliseconds 200  
        }
        Start-Sleep -Milliseconds 500
        #and a litte bit longer until we can control it
        $R = &"C:\Program Files (x86)\Fiddler2\ExecAction.exe" $action
        while ( $R -like 'ERROR: Fiddler window was not found.' ) {
            Start-Sleep -Milliseconds 200
            $R = &"C:\Program Files (x86)\Fiddler2\ExecAction.exe" $action
        }
    }
}

function Start-FiddlerCapture  {
[CmdletBinding()]
[OutputType([void])]    
param (
    [Switch]$Show    
)   
    Ensure-Fiddler -Show:$Show
    if ($Show) { 
        &"C:\Program Files (x86)\Fiddler2\ExecAction.exe" Show
    } else {
        &"C:\Program Files (x86)\Fiddler2\ExecAction.exe" hide
    }
    &"C:\Program Files (x86)\Fiddler2\ExecAction.exe" clear
    &"C:\Program Files (x86)\Fiddler2\ExecAction.exe" start
 
}

function Save-FiddlerCapture  {
[CmdletBinding()]
[OutputType([void])]    
Param (
    $fileName = 'C:\Users\josverl\OneDrive\PowerShell\PSAppInsights\Tests\LastSession.json',
    $ProcessID = $PID,
    [Switch]$Show
)
    Ensure-Fiddler -Show:$Show
    if ($Show) { 
        &"C:\Program Files (x86)\Fiddler2\ExecAction.exe" Show
    } else {
        &"C:\Program Files (x86)\Fiddler2\ExecAction.exe" hide
    }
    &"C:\Program Files (x86)\Fiddler2\ExecAction.exe" stop
    #Select Only the sessions sent by this PowerShell process 
    &"C:\Program Files (x86)\Fiddler2\ExecAction.exe" "select @col.Process :$ProcessID"
    &"C:\Program Files (x86)\Fiddler2\ExecAction.exe" "DumpJson $FileName"

    #Wait for File 
    while(!(Test-Path $FileName)) {    
        Start-Sleep -Milliseconds 200  
    }  
    #Anda little more to avoid problems while loading later
    Start-Sleep -Milliseconds 100 
 }

function Read-FiddlerAICapture {
[CmdletBinding()]
[OutputType([PSObject[]])]
Param (
    $fileName = 'C:\Users\josverl\OneDrive\PowerShell\PSAppInsights\Tests\LastSession.json',
    [Switch]$QuickPulse
)

    $Capture = Get-Content $fileName |Convertfrom-json 
    #$Capture.log.entries= $Capture.log.entries | Where { ($_.request.url -like 'https://*.services.visualstudio.com/*') }      

    if ($QuickPulse) {
        #Filter for Only QuickPulse 
        #Make sure to get an array 
        $Capture.log.entries = @($Capture.log.entries| Where { ($_.request.url -like 'https://rt.services.visualstudio.com/QuickPulseService.svc/*') })
        return $Capture
    } else {
        #Filter for only AI traffic
    
        $Capture.log.entries = @( $Capture.log.entries | Where { ($_.request.url -like 'https://dc.services.visualstudio.com/v2/track') })
        #Expand the Telemetry data from the post and the response body

        for ($n = 0; $n -lt $Capture.log.Entries.Count; $n++) {
            #--------------------------------------------
            #Expand the Telemetry data from the post body 
            $Post = $Capture.log.Entries[$n].request.postData.text
            
            #1 JSON Object per Line 
            $Telemetry = ($post.Split("`r") ) | ConvertFrom-Json 
            
            $Capture.log.Entries[$n] | Add-Member -Name 'AITelemetry' -MemberType NoteProperty -Value $Telemetry -Force
            #Get the AI response 
            $AIResponse = $Capture.log.Entries[$n].response.content.text | ConvertFrom-Json -ErrorAction SilentlyContinue
            $Capture.log.Entries[$n] | Add-Member -Name 'AIResponse' -MemberType NoteProperty -Value $AIResponse -Force
        }

        $AllTelemetry = @( $Capture.log| foreach { Write-Output $_.AITelemetry } )
        $AllResponses = @( $Capture.log| foreach { Write-Output $_.AIResponse } )

        $Capture | Add-Member -Name 'AllTelemetry' -MemberType NoteProperty -Value $AllTelemetry -Force
        $Capture | Add-Member -Name 'AllResponses' -MemberType NoteProperty -Value $AllResponses -Force

        Return  $Capture
    }
}

function Stop-Fiddler {
[CmdletBinding()]
[OutputType([void])]    
param ( [Switch]$wait)    
    #Make Sure fiddler is started 
    if ((Get-Process -Name 'Fiddler' -ErrorAction SilentlyContinue)) { 
        $R = &"C:\Program Files (x86)\Fiddler2\ExecAction.exe" "quit"
    }
    if ($wait) {
        #Wait for Fiddler to start 
        while((Get-Process -Name 'Fiddler' -ErrorAction SilentlyContinue)) {    
            Start-Sleep -Milliseconds 200  
        }
    }
}

<#

Fiddlerscript function 

    // The OnExecAction function is called by either the QuickExec box in the Fiddler window,
    // or by the ExecAction.exe command line utility.
    static function OnExecAction(sParams: String[]): Boolean {

-=-=- Start 
	case "dumpjson":
		// JSONDUMP MARKER 		
        var oSessions; 
        var uxString = "All";
		var oExportOptions = FiddlerObject.createDictionary(); 
		var FileName = CONFIG.GetPath("Captures") 
        // get all / selected sessions
        if ( FiddlerApplication.UI.lvSessions.SelectedCount > 0) {
            oSessions = FiddlerApplication.UI.GetSelectedSessions()          
            uxString = "Selected"
        } else { 
            oSessions = FiddlerApplication.UI.GetAllSessions()
            uxString = "All"
        }
        // First Param = full filename
        if ( sParams.length <= 1 || sParams[1] == "") {
            FileName = CONFIG.GetPath("Captures") + "\Sessions-"+uxString+".json"
        } else {
            FileName = sParams[1]
        }
		oExportOptions.Add("Filename", FileName ); 
		oExportOptions.Add("MaxTextBodyLength", 1024); 
		oExportOptions.Add("MaxBinaryBodyLength", 16384); 
		FiddlerApplication.DoExport("HTTPArchive v1.2", oSessions, oExportOptions, null); 
		FiddlerObject.StatusText = "Dumped "+ uxString +" sessions to JSON in " + FileName ;
		return true;			
			
-=-=- end

#>

