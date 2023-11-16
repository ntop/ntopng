v1.6
Improves the quality and safety of the code and fixes a bug
--
v1.5 
includes improved error handling
--
v1.4
It is no longer necessary to have multiple copies of the script hosted on your server to download it with different configs as it was in v1.3.  Now the configs are separated from the script.

Note my assumption is that you would take the script I provide and would edit the constants section before hosting it on your server.  Then on first run, it will take those constants that you have defined and create a separate file next to the script containing the configuration.  You can edit that file (details in the script notes included in the script) and customise it for that router.  The configuration will be retained even if the script is updated.
Enjoy!
--
v1.3
I have previously provided a script for running on Ubiquiti edgerouters being used for nprobe.  The script can be used to automatically populate the ntopng server hostname information from DHCP hostname information on the edge router so that you have more meaningful device information than just MAC/IP addresses in the data seen in the ntopng server.

This is an updated release of that script that allows you to store a master copy of the script on a central server you manage and for the script to automatically update if you have updated the master copy.  This therefore provides centralised release management for the script if you choose to enable that functionality.  Note that it is also possible to use multiple centrally managed versions of the scripts with different settings in them if that is your desire.

The other improvement is that if you make use of the hostnamesubstitute functionality to allow you to replace the automatically detected device names with names that are more meaningful, you can now also centrally manage these in the same way.

As always, the documentation is in the script itself.  I hope you find this helpful!
--
v1.2
Apologies, I accidentally uploaded the version with a formatting error.  Here is the one I meant to upload!
--
v1
Hi NTOPNG community.  This message is relevant to anyone using a Ubiquiti edge router as an nprobe device.

This is a script that I have written to run on Ubiquiti Edge routers when they are used as an nprobe and it serves two purposes.  
1. Make the data in ntopng more complete by updating device names into NTOPNG via API
2. can optionally be used to send telegram notifications when a device first appears on a network within a defined time period.

All the documentation is included in the script and it is released as public domain.

I hope you find it helpful