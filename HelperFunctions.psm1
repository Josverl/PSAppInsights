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
function getCallerInfo ($level = 2)
{
[CmdletBinding()]
    $dict = New-Object 'system.collections.generic.dictionary[[string],[string]]'
    try { 
        #Get the caller info
        $caller = (Get-PSCallStack)[$level] 
        #get only the script name
        $ScriptName = '<unknown>'
        if ($caller.Location) {
            $ScriptName = ($caller.Location).Split(':')[0]
        }

        $dict.Add('ScriptName', $ScriptName)
        $dict.Add('ScriptLineNumber', $caller.ScriptLineNumber)
        $dict.Add('Command', $caller.Command)
        $dict.Add('FunctionName', $caller.FunctionName)

        return $dict

    } catch { return $null}
}

<#
    Helper function to get the calling script or module version#>
function getCallerVersion 
{
[CmdletBinding()]
param(
    [int]$level = 2
)
    try { 
        #Get the caller info
        $caller = (Get-PSCallStack)[$level] 
        #get only the script name
        $ScriptName = '<unknown>'
        if ($caller.Location) {
            $ScriptName = ($caller.Location).Split(':')[0]
        }

        $dict.Add('ScriptName', $ScriptName)
        $dict.Add('ScriptLineNumber', $caller.ScriptLineNumber)
        $dict.Add('Command', $caller.Command)
        $dict.Add('FunctionName', $caller.FunctionName)

        return $dict

    } catch { return $null}
}

<#
    Helper function to get the calling script or module version
#>
function getCallerVersion 
{
[CmdletBinding()]
param(
    #Get version from X levels up in the call stack
    [int]$level = 1
)
    Write-Verbose "getCallerVersion -level $level"
    [Version]$V = $null
    try { 
        #Get the caller info
        $caller = (Get-PSCallStack)[$level] 
        #if script
        if ( -NOT [string]::IsNullOrEmpty( $caller.ScriptName)){
            $info = Test-ScriptFileInfo -Path $caller.ScriptName -ErrorAction SilentlyContinue
            if ( $info ) {
                $v = $info.Version
                Write-Verbose "getCallerVersion found script version $v"
                return $v
            }
        }       
    } catch { }
    Try {
        #try module info based on the name, but with a psd1 extention
        $Filename = [System.IO.Path]::ChangeExtension( $caller.ScriptName, 'psd1')
        $info = Test-ModuleManifest -Path $Filename -ErrorAction SilentlyContinue
        if ( $info ) {
            $v = $info.Version
            Write-Verbose "getCallerVersion found Module version $v"
            return $v
            break;
        }
    } catch {} # Continue 

    try {
        #try to find a version from the path and folder names 
        $Folders= @( $Filename.Split('\') )
        $found = $false
        foreach( $f in $Folders ) {
            Try { $V = [version]$f ; $found = $true} 
            catch {}
        }
        if ($found) {
            #return last found version
            Write-Verbose "getCallerVersion found Folder version $v"
            return $v
        }
    } catch {
        Write-Verbose "getCallerVersion no version found"         
        return $v
    }
    Write-Verbose "no version found"
    return $v
}


<#
 # Credits: Joel Bennet
 # http://poshcode.org/4968

 Chnaged to not allow Nulls by default 
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

