To test our project, first build the project.
Then test it locally by running it and checking its logs.
You can additional test the webvnc server by visiting "https://localhost:5800/" in your browser.
Only continue from this step if no errors occured and everything worked.
To be extra sure you can decide to additionally test the x86 version locally aswell at this point.
If that worked, push to dockerhub and upload the "./unraid/my-everything-search.xml" to my nas as "/boot/config/plugins/dockerMan/templates-user/my-everything-search.xml" using your ssh mcp.
Wait for me to update the container manually via "https://192.168.2.10/Docker/UpdateContainer?xmlTemplate=edit:/boot/config/plugins/dockerMan/templates-user/my-everything-search.xml"
When i told you that i updated and tested the container, check its logs via ssh to get a final confirmation.
