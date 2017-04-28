#Assumes current folder to be the location where the packages are to be installed

#Make sure to update Nuget 
.\nuget.exe update -self
#Now install the packages as specified 
.\nuget.exe install .\packages.config -o . 

