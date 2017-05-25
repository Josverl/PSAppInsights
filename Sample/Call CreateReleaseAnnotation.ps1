
     #$iKey = 'b437832d-a6b3-4bb4-b237-51308509747d' #AI PowerShell
     $AppID = '22a37615-a433-4b2e-89e7-d3b924f57a6a' #Can this be looked up ?
    $APIKey = 'ux8ab05zo1s0wksvjitc67ksyswcxj1pywria7i4' 

  .  .\CreateReleaseAnnotation.ps1 
  #Default  
  CreateReleaseAnnotation   -Verbose -applicationId $AppID  -apiKey $APIKey `
                            -releaseName "Release JOS T=0" `
                            -releaseProperties @{
                                "ReleaseDescription"="a description";
                                "TriggerBy"= $env:USERNAME } 

#10 minutes ago 

  $T10 = CreateReleaseAnnotation   -Verbose -applicationId $AppID  -apiKey $APIKey `
                            -releaseName "Release JOS T=-10" -PassThrough `
                            -eventDateTime ( (Get-date).AddMinutes(-10)) `
                            -releaseProperties @{
                                "ReleaseDescription"="a description";
                                "TriggerBy"= $env:USERNAME } 

#Related 

  $T05 = CreateReleaseAnnotation   -Verbose -applicationId $AppID  -apiKey $APIKey `
                            -releaseName "Release JOS T=-05" -PassThrough `
                            -eventDateTime ( (Get-date).AddMinutes(-10)) `
                            -RelatedAnnotationID $T10.ID `
                            -releaseProperties @{
                                "ReleaseDescription"="a description";
                                "TriggerBy"= $env:USERNAME } 

$T10 , $T05 | ft