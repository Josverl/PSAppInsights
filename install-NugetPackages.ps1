cd .\PSAppInsights

#Make sure to update Nuget 
.\nuget.exe update -self
#Now install the packages as specified 
.\nuget.exe install .\packages.config -o .

