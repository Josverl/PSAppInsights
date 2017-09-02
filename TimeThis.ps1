
<#
.Synopsis
    A simple way to determine the time that needed to execute a section of code 
    This can be done by putting simple TimeThis statement in the script, and do not require more complex measure-command structures.
.DESCRIPTION
    Thim
    The -Action parameter can contain the folowing format placeholders to allow inserting the duration 
    {0}     Milliseconds
    {1}     Seconds
    {2}     Minutes
    {3}     hh:mm:ss.milliseconds
    {5}     Duration (raw)

.EXAMPLE
    1..5 | %{
        TimeThis "Step $_"
        Sleep -Seconds (Get-Random -Maximum 3)
    }
    TimeThis -Last

    .EXAMPLE

    TimeThis "Start Demo" 
    Start-Sleep 1 
    TimeThis  "Next Step" -Format Seconds
    Start-Sleep 1
    TimeThis  "{4}`t Custom Format" -Format None
    Start-Sleep 1
    TimeThis -Last

.EXAMPLE

    TimeThis "Start Demo" 
    Start-Sleep 1 
    TimeThis  "{4}`t Custom Format" -Format None
    Start-Sleep 1
    TimeThis -Last


.NOTES
    todo: PassThrough
.FUNCTIONALITY
    The functionality
#>
function TimeThis 
{
    [CmdletBinding(
        DefaultParameterSetName="Activity"
    )]    
    Param (
        #Identifier for the next aactivity or commands that should be measured        
        [Parameter(Position=0,ParameterSetName="Activity")]
        $Action = "Activity:`t{3}",

        #Specify to indicate the first activity, Overrides the current running timer if any.
        [Parameter(ParameterSetName="Activity")]
        [switch]$First, 

        #Specifies in what format the duration should be reported. Default = Full
        [Parameter(ParameterSetName="Activity")]
        [ValidateSet('Full','Seconds','Milliseconds','Minutes','None')]
        [string]$Format = 'Full',

        #the spaces appended bewtween the Activity and the duration. Default = TAB
        [Parameter(ParameterSetName="Activity")]
        $spacer = "`t",

        #Specify -Last to finalise the current running duration timer, and log the last action.
        [Parameter(ParameterSetName="Last")]
        [switch]$Last
    )
    #Add a timestamp to the Action in the requested format
    switch ($format) {
        'Milliseconds' { $Action += $spacer + '{0}' }
        'Seconds' { $Action += $spacer + '{1}' }
        'Minutes' { $Action += $spacer + '{2}' }                
        'Full' { $Action += $spacer + '{3}' }
    }

    if ( $First `
         -or $Script:_Timer -eq $null `
         -or $Script:_Timer.IsRunning -eq $false ) {
        #todo If script does not contain curly brackets 
        if ( -not $Last ) {
            $Script:LastAction = $Action
            #Start a new timer 
            $Script:_Timer = [System.Diagnostics.Stopwatch]::StartNew()
        }
    } else { 
        $Duration = $Script:_Timer.Elapsed
        $message = $Script:LastAction -f $Duration.TotalMilliseconds, $Duration.TotalSeconds, $Duration.TotalMinutes, $Duration.ToString(), $Duration
        Write-Host $message
        if ( $Last ) {
            $Script:_Timer.Stop()
            $Script:_Timer = $null
            $Script:LastAction = $null
        } else {
            $Script:_Timer.Restart()
            $Script:LastAction = $Action
        }
    }
}




TimeThis "Start Demo" 
Start-Sleep 1 
TimeThis  "Next Step" -Format Seconds -First #Overrides the current running timner
Start-Sleep 1
TimeThis -Last



TimeThis "Stap 1`t {3}" 
Sleep -Seconds (Get-Random -Maximum 3)


TimeThis "Stap 2`t {3}"
Sleep -Seconds (Get-Random -Maximum 3)

1..5 | %{
    TimeThis "Stap 3.$_ `t{0}`t{1}`t{2}`t{3}"
    Sleep -Seconds (Get-Random -Maximum 3)
}

TimeThis -Last

