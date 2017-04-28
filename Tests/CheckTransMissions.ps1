

<#
Add fiddlerscript to save the SAZ and TXT forms
    FiddlerScript : OnExecAction 

    case "saveselected":
        FiddlerObject.UI.actSaveSessionsToZip(CONFIG.GetPath("Captures") + "selected.saz");
        FiddlerObject.UI.actSaveSessions(CONFIG.GetPath("Captures") + "selected.txt",0);
        FiddlerObject.StatusText = "Saved Selected sessions to " + CONFIG.GetPath("Captures") + "selected.saz";
        return true; 



#>
if ($false) {
Start-Process "C:\Program Files (x86)\Fiddler2\Fiddler.exe" 

#&"C:\Program Files (x86)\Fiddler2\ExecAction.exe" hide
&"C:\Program Files (x86)\Fiddler2\ExecAction.exe" Show

&"C:\Program Files (x86)\Fiddler2\ExecAction.exe" clear
&"C:\Program Files (x86)\Fiddler2\ExecAction.exe" start

#init a client and send basic PII information for correlation
#this incudes the username and the machine name
$Client = New-AIClient -Key $key -AllowPII 
Send-AIEvent "Allow PII" -Flush


&"C:\Program Files (x86)\Fiddler2\ExecAction.exe" stop
#Select the sessions
&"C:\Program Files (x86)\Fiddler2\ExecAction.exe" "@dc.services.visualstudio.com"

&"C:\Program Files (x86)\Fiddler2\ExecAction.exe" SaveSelected 


ii "C:\Users\josverl\OneDrive - Microsoft\Documents\Fiddler2\Captures"
}
$capturedtext = Get-Content "C:\Users\josverl\OneDrive - Microsoft\Documents\Fiddler2\Captures\selected.txt" #-raw 


$newCall = $True

$capturedtext | %{

        if ($newCall){
            $Call = New-Object PSObject  -Property @{Sent = '';Recieved = '';SentBody = '';RecievedBody = ''} 
            $newCall = $False
            $InSend = $True; $InBody = $False
        }
        if ($_ -like  '-----------------------------------------*') {
                Write-Verbose -Verbose "> "
                Write-Output $Call
                $newCall = $True ;
                #continue;
        }
        if ($_ -eq  '' -and $call.Recieved -ne '') {
            $InBody = $true
        }
        if ($_ -like  'HTTP/*') {
            $InSend = $False
            $InBody = $False
        }

        if ($InSend) {
            $Call.Sent = $Call.Sent + $_
            if ($inBody) {
                $Call.SentBody = $Call.SentBody + $_
            }
        } Else {
            $Call.Recieved = $Call.Recieved + $_
            if ($inBody) {
                $Call.RecievedBody = $Call.RecievedBody + $_
            }

        }        
        
} | FL

#Now split on the seperator string 
#Fail
$Sessions = $capturedtext.Split( '------------------------------------------------------------------')
$Sessions.Count