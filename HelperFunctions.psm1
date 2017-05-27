<#------------------------------------------------------------------------------------------------------------------
    Helper Functions 
--------------------------------------------------------------------------------------------------------------------#>


<#
 helper function 
 Get-StringHash Credits : Jeff Wouters
 ref: http://jeffwouters.nl/index.php/2013/12/Get-StringHash-for-files-or-strings/
#>

function Get-StringHash {
    [cmdletbinding()]
    param (
        [parameter(mandatory=$false,parametersetname="String")]$String,
        [parameter(mandatory=$false,parametersetname="File")]$File,
        [parameter(mandatory=$false,parametersetname="String")]
        [validateset("MD5","SHA1","SHA256","SHA384","SHA512","RIPEMD160")]
        [parameter(mandatory=$false,parametersetname="File")]
        [validateset("MD5","SHA1","SHA256","SHA384","SHA512","RIPEMD160")]
        [string]$HashType = "MD5"
    )
    switch ($PsCmdlet.ParameterSetName) { 
        "String" {
            $StringBuilder = New-Object System.Text.StringBuilder 
            [System.Security.Cryptography.HashAlgorithm]::Create($HashType).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))| ForEach-Object {
                [Void]$StringBuilder.Append($_.ToString("x2")) 
            }
            $Object = New-Object -TypeName PSObject
            $Object | Add-Member -MemberType NoteProperty -Name 'String' -value $String
            $Object | Add-Member -MemberType NoteProperty -Name 'HashType' -Value $HashType
            $Object | Add-Member -MemberType NoteProperty -Name 'Hash' -Value $StringBuilder.ToString()
            $Object
        } 
        "File" {
            $StringBuilder = New-Object System.Text.StringBuilder
            $InputStream = New-Object System.IO.FileStream($File,[System.IO.FileMode]::Open)
            switch ($HashType) {
                "MD5" { $Provider = New-Object System.Security.Cryptography.MD5CryptoServiceProvider }
                "SHA1" { $Provider = New-Object System.Security.Cryptography.SHA1CryptoServiceProvider }
                "SHA256" { $Provider = New-Object System.Security.Cryptography.SHA256CryptoServiceProvider }
                "SHA384" { $Provider = New-Object System.Security.Cryptography.SHA384CryptoServiceProvider }
                "SHA512" { $Provider = New-Object System.Security.Cryptography.SHA512CryptoServiceProvider }
                "RIPEMD160" { $Provider = New-Object System.Security.Cryptography.CryptoServiceProvider }
            }
            $Provider.ComputeHash($InputStream) | Foreach-Object { [void]$StringBuilder.Append($_.ToString("X2")) }
            $InputStream.Close()
            $Object = New-Object -TypeName PSObject
            $Object | Add-Member -MemberType NoteProperty -Name 'File' -value $File
            $Object | Add-Member -MemberType NoteProperty -Name 'HashType' -Value $HashType
            $Object | Add-Member -MemberType NoteProperty -Name 'Hash' -Value $StringBuilder.ToString()
            $Object           
        }
    }
}


<#
    Helper function to get the script and the line number of the calling function
#>
function getCallerInfo 
{
[CmdletBinding()]
param(
    #number of levels to go back in the call stack 
    [ValidateRange(1,  99)]
    [int]$level = 2,
    [Switch]$FullStack 

)
    $dict = New-Object 'system.collections.generic.dictionary[[string],[string]]'
    try { 
        #Get the caller info
        $Stack = Get-PSCallStack
        #The level to track back should not exceed the depth of the callstack, so limit it where needed 
        $level = [Math]::Min( $level, $Stack.Length -1 )
        #$caller = $Stack[$level] 
        #Get Base information straight from the Stack 
        $dict.Add('Command',            $Stack[$level].Command )
        $dict.Add('ScriptLineNumber',   $Stack[$level].ScriptLineNumber)
        $dict.Add('Position',           $Stack[$level].Position)
        $dict.Add('FunctionName',       $Stack[$level].FunctionName)
        $dict.Add('Location',           $Stack[$level].Location)

        #Extract the scriptname from the location
        $Scriptname = $Stack[$level].Location
        if ( [string]::IsNullOrEmpty( $Scriptname ) -ne $true ) {
            #Split  on : and take the first node only
            
            $dict.Add('Script',   $Scriptname.Split(':')[0])
        }
         #  Also Add the complete Stack 
        If ($FullStack) {
            #$ReportLevels = 1 + $Stack.Count - $level
            $StackTrace = $Stack | Select -Skip $level -Property ScriptName,ScriptLineNumber,FunctionName,Command,Location,Arguments | ConvertTo-Json -Compress
            $dict.Add( 'PSCallStack', $StackTrace)
        }
  
        return $dict

    } catch { return $null}
}

<#
    Helper function to get the calling script or module version
    checks Script, Invocation Info, Module and Folder names
#>
function getCallerVersion 
{
[CmdletBinding()]
param(
    #Get version from X levels up in the call stack
    [int]$level = 2 #Use 2 as default as this is mostly an internal function, so we need to reach one additional Stacklevel up 
)

    #Get the caller info
    $Stack = Get-PSCallStack
    
    #The level to track back should not exceed the depth of the callstack, so limit it where needed 
    $level = [Math]::Min( $level, $Stack.Length -1 )
    Write-Verbose "getCallerVersion -level $level"
    #Default Caller Version to 0.0
    [Version]$CallerVersion = '0.0'
    try { 
        #Get the caller info
        $caller = $Stack[$level] 
        
        #if script
        if ( -NOT [string]::IsNullOrEmpty( $caller.ScriptName)){
            Write-Verbose "Try Test-ScriptFileInfo -Path $($caller.ScriptName)"
            $info = Test-ScriptFileInfo -Path $caller.ScriptName -ErrorAction SilentlyContinue
            if ( $info ) {
                $CallerVersion = $info.Version
                Write-Verbose "getCallerVersion found script version $CallerVersion"
                return $CallerVersion
            }
        } else {
            Write-Debug 'No scriptname'
        }
              
    } catch { 
        Write-Verbose 'catch error during script test' 
    } 
    Try {
        if (-NOT [string]::IsNullOrEmpty(  $Caller.InvocationInfo.MyCommand)){
            Write-Verbose "Try to extract version info from Stack[x].InvocationInfo.MyCommand "
            #define Regex to look for version 
            $rxGetVersion = [regex]'\.VERSION\s+(?<Version>[\d\.]+)'

            if ($Caller.InvocationInfo.MyCommand.ToString() -match $rxGetVersion ) {
                #version is a named capture block 
                $CallerVersion =  $Matches['Version']

                Write-Verbose "getCallerVersion found InvocationInfo.MyCommand version $CallerVersion"
                return $CallerVersion
            }
        } else {
            #convert to json
            $InvocationJSON = $Caller.InvocationInfo | ConvertTo-Json 
            Write-Verbose "Try to extract version info from Stack[x].InvocationInfo"
            #define Regex to look for version 
            $rxGetVersion = [regex]'\.VERSION\s+(?<Version>[\d\.]+)'

            if ($InvocationJSON -match $rxGetVersion ) {
                #version is a named capture block 
                $CallerVersion =  $Matches['Version']

                Write-Verbose "getCallerVersion found InvocationInfo version $CallerVersion"
                return $CallerVersion
            }
        }

     } catch { 
        Write-Verbose 'catch error during InvocationInfo test' 
    } 
    Try {
        
        $Filename = [System.IO.Path]::ChangeExtension( $caller.ScriptName, 'psd1')
        Write-Verbose "Try Test-ModuleManifest -Path $Filename"
        $info = Test-ModuleManifest -Path $Filename -ErrorAction SilentlyContinue
        if ( $info ) {
            $CallerVersion = $info.Version
            Write-Verbose "getCallerVersion found Module version $CallerVersion"
            return $CallerVersion
        }
    } catch { 
        Write-Verbose 'catch error during module test' 
    } 

    try {
        Write-Verbose "try to find a version from the path and folder names"
        $Folders= @( $Filename.Split('\') )
        $found = $false
        foreach( $f in $Folders ) {
            Try { 
                Write-Verbose "evaluating Path fragment [$f]"
                $CallerVersion = [version]$f ; $found = $true
            } 
            catch {}
        }
        if ($found) {
            #return last found version
            Write-Verbose "getCallerVersion found Folder version $CallerVersion"
            return $CallerVersion
        }
    } catch {
        Write-Verbose "getCallerVersion no version found"         
        return $CallerVersion
    }
    Write-Verbose "no version found"
    return $CallerVersion
}

<#
 # Credits: Joel Bennet
 # http://poshcode.org/4968

 Changed to not allow Nulls by default 
#>


function ConvertTo-Hashtable {
  #.Synopsis
  #   Converts an object to a hashtable of property-name = value 
  PARAM(
    # The object to convert to a hashtable
    [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
    $InputObject,

    # Forces the values to be strings and converts them by running them through Out-String
    [switch]$AsString,  

    # If set, allows each hashtable to have it's own set of properties, otherwise, 
    # each InputObject is normalized to the properties on the first object in the pipeline
    [switch]$jagged,

    # If set, empty properties are Included
    [switch]$AllowNulls
  )
  BEGIN { 
    $headers = @() 
  }
  PROCESS {
    if(!$headers -or $jagged) {
      $headers = $InputObject | get-member -type Properties | select -expand name
    }
    $output = @{}
    if($AsString) {
      foreach($col in $headers) {
        if($AllowNulls -or ($InputObject.$col -is [bool] -or ($InputObject.$col))) {
          $output.$col = $InputObject.$col | out-string -Width 9999 | % { $_.Trim() }
        }
      }
    } else {
      foreach($col in $headers) {
        if($AllowNulls -or ($InputObject.$col -is [bool] -or ($InputObject.$col))) {
          $output.$col = $InputObject.$col
        }
      }
    }
    $output
  }
}

