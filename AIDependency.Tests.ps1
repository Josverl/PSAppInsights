Param ( 

    #switch to test the installed module after initial test deployment  
    [switch]$TestInstalledModule
)

Get-Module -Name 'PSAppInsights' -All | Remove-Module -Force -ErrorAction SilentlyContinue
if ($TestInstalledModule) { 
    Write-Verbose 'Load locally installed module' -Verbose
    $M = Import-Module -Name PSAppInsights -PassThru
    $m | FT Name,version, Path

} else { 
    #Load Module under development 
        Import-Module ".\PSAppInsights.psd1" -Force  
}

Describe 'AI Dependency Nested Module' {

    BeforeAll {
        #AI Powershell-test 
        $key = "b437832d-a6b3-4bb4-b237-51308509747d"
        $Watch1 = new-Stopwatch
    }
    
    AfterAll {
        Remove-Module -Name AIDependency -Force -ErrorAction SilentlyContinue
    }

    It 'can start a AI Client with dependency tracking' {
        $client = New-AIClient -Key $key -Initializer Dependency

        {$c2 = New-AIClient -Key $key -Initializer Dependency} | Should not Throw
        $client | Should not be $null
    }

    It 'can start a Stopwatch' {
        $Watch1 | should not be $null
        $Watch1.GetType()  | should be 'System.Diagnostics.Stopwatch'
    }
    It 'Depedency can use a stopwatch' {
        $Watch1.Stop()
        { Send-AIDependency -StopWatch $Watch1 -Name "TEST Dept." } | Should not Throw
    } 
    
    It 'Dependency can use a Duration - 1' {
         $TS = Measure-Command { Sleep (Get-Random 1 ) }
        { Send-AIDependency -TimeSpan $TS -Name "TEST Dept." } | Should not Throw
    }
    It 'Dependency can use a Duration from the pipeline - 2'  {

        {  Measure-Command { Sleep (Get-Random 1 ) } | Send-AIDependency -Name "TEST Dept." } | Should not Throw
    
    }
    $TS = Measure-Command { Sleep (Get-Random 1 ) }
    It 'Dependency can Send Failure'  {
        {   
            Send-AIDependency -Name "TEST Dept." -TimeSpan $TS -Success $false -ResultCode 500 
        
         } | Should not Throw
    }

    It 'Dependency can be set to SQL'  {
        {   
            Send-AIDependency -Name "TEST SQL." -TimeSpan $TS -Success $True -DependencyKind SQL -CommandName "DROP *"
        
         } | Should not Throw
    }

    It 'Dependency can be set to HTTP'  {
        {   
            Send-AIDependency -Name "TEST HTTP" -TimeSpan $TS -Success $True -DependencyKind HTTP -CommandName "http://powershellgallery.com"
        
         } | Should not Throw
    }

}
