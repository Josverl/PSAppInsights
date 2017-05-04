import-module .\FiddlerTests.psm1 -DisableNameChecking -Force

#init a client and send basic PII information for correlation
#this incudes the username and the machine name
$fileName = 'C:\Users\josverl\OneDrive\PowerShell\PSAppInsights\Tests\LastSession.json'

#Stop-Fiddler -wait
Start-FiddlerCapture 

$key = "b437832d-a6b3-4bb4-b237-51308509747d" #AI Powershell-test 
$Client = New-AIClient -Key $key -AllowPII 
Send-AIEvent "Allow PII" -Flush
Send-AIEvent "Allow PII" -Flush
Save-FiddlerCapture -FileName  $fileName 
$Capture = Read-FiddlerAICapture -FileName  $fileName



"Read {0} Sessions, Containing {1} Telemetryitems" -f $Capture.log.entries.Count, $Capture.AllTelemetry.Count

$Capture.AllTelemetry | Format-Table
$Capture.log.entries
Write-host 'Done'

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

