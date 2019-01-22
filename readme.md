#Preqs for building the module

* The following modules are used 
    * PSake `install-module psake` is used  for the build script 
    * Pester `install-module pester` is used for testing 
    * Credential Manager `install-module CredentialManager` is used to retrieve the PSGallery API Key
        * `Get-StoredCredential  -Target 'PSGallery:NuGetApiKey'`
    * nuget.exe is needed in order to download new AI modules 
    * create a (file based) PSRepository for testing
        * md c:\Develop\PSRepo-Dev 
        * `Register-PSRepository -Name Dev -SourceLocation 'c:\Develop\PSRepo-Dev' -InstallationPolicy Trusted`
    * Fiddler2/fiddler4 is used in testing to verify the information send to/from the AI 
        * Install from https://www.telerik.com/download/fiddler/fiddler4
        * Fiddler **must** be configured to [decrypt HTTPS traffic](http://docs.telerik.com/fiddler/Configure-Fiddler/Tasks/DecryptHTTPS)
        * A number of the tests use Fiddler to 
            * capture the traffic, 
            * select the sessions from the current powershell process 
            * export these to JSon 
            * compare that with the expected Requests and/or Responses
        * For this a custom onExecAction command must be added to Fiddler to allow exporting the selected sessions to a json file. 
        


# Download dependencies 
* Verify the `packages.json` file 
* Run `nuget restore -packagesdirectory .` to download the needed packages 
* Fiddler 

#Build the module  
Start the build by running `Invoke-Psake`
the build will run though the folling steps 
The default build target is **6. TestInstall** 

1. Test         - Run the Pester test suite in the current folder (dev environment)
2. Clean        - Clean the .\Release folder 
3. Copy         - Copy items to the release folder
4. Sign         - No signing ( this step is skipped for Modules)
5. TestPublish  - Publish the module to a DEV Powershell repository (PSRepository -Name Dev )
6. **TestInstall**  - Installs the module from the DEV PSRepository in the current users local scope (-Force -Scope CurrentUser) 
7. Publish      - Publishes the Module to the **PSGallery** (Key from Stored Network Credentials)
8. Install      - Installs the module from the **PSGallery** in the current users local scope (-Force -Scope CurrentUser)

## Testing
Testing is part of the build tasks but can also be run seperatly by running `Invoke-Pester`. This will run all tests.
Testing assumes that an Application Insights Instance is available and reachable for testing purposes. This should preferable not be your production instance.
Teh AIKey for this is currently part of the test suite 



> It should be noted that due to the fact that the Powershell / .Net architecture  does not allow DLLS to be unloaded from a process, each test run MUST be run in a seperate process

> If you use VSCode, a Task `Run Pester Tests` has been defined that will run these tests in a separate PowerShell process

#Extending Fiddler to allow Traffic inspection in Tests

A number of the tests use Fiddler to 
    * capture the traffic between the Test script and the AI Service 
    * select the sessions from the current powershell process 
    * export these to JSon 
    * compare that with the expected Requests and/or Responses 


You can easily add the new command by editing your FiddlerScript.  Start Fiddler, Click Rules | Customize Rules.  Scroll down to the OnExecAction function and simply add your own commands. ( look for the end of the file / case statement and )

Look for the 
```javascript
// The OnExecAction function is called by either the QuickExec box in the Fiddler window,
// or by the ExecAction.exe command line utility.
static function OnExecAction(sParams: String[]): Boolean {
    ...
    ...

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
                
   
```

See .\tests\dumpjson-fiddler-command.js


##Testing the Tests
If you are developing and testing the Test, please noate that you may/will need to account for the same.
in VSCode this can be done by the Debug Configuration `PowerShell Launch Current File in Temporary Console`


#Updating to newer AI Dlls

* nuget.exe in your path 
* check Nuget.org for the relevant (stable) versions of of the AI packages
* Update  the `packages.json` file 
* update the `PSAppInsights.psd1` 
    * with the same AI versions 
    * update the Module version number 
* remove any/all older versions of the AI Dlls [optional , but recommended to reduce package size]
* Run `nuget restore -packagesdirectory .` to download the new packages 

