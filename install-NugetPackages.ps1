cd .\PSAppInsights

#Make sure to update Nuget 
.\nuget.exe update -self
#Now install the packages as specified in ther packages.config file 
.\nuget.exe install .\packages.config -o .

