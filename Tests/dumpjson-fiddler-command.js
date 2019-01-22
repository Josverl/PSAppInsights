

        
    // The OnExecAction function is called by either the QuickExec box in the Fiddler window,
    // or by the ExecAction.exe command line utility.
    static function OnExecAction(sParams: String[]): Boolean {        
        
        //...

        // custom fiddler command 'dumpjson' to dump selected to JSON 
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
        // end custom command
        
        default:
            if (sAction.StartsWith("http") || sAction.StartsWith("www.")) {
                System.Diagnostics.Process.Start(sParams[0]);
                return true;
            }
            else
            {
                FiddlerObject.StatusText = "Requested ExecAction: '" + sAction + "' not found. Type HELP to learn more.";
                return false;
            }
    }

