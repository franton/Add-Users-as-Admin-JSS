#!/bin/bash

# Script to grab the authorised admin users and grant those rights to a target computer at logout.

# Author	  : r.purves@arts.ac.uk
# Version 1.0 : 02-02-2013 - Initial Version
# Version 1.2 : 08-02-2013 - Fixed windows horrible habit of appending \r to end of lines
# Version 1.3 : 08-03-2013 - Ignores initial part of machine name to cope with wildcards
#                            This is so we can specify dual boot computers with 1 line.
# Version 1.4 : 21-03-2013 - Fixes bugs introduced by previous change. Unary operations.
# Version 1.5 : 10-09-2013 - Added read only user account for mounting sysvol share

# Version 2.0 : 29-10-2013 - Scrapped all work and started again. This time the script
#							 interrogates an extension attribute in the JSS for the user info

# Set up needed variables here

ethernet=$(ifconfig en0|grep ether|awk '{ print $2; }')
apiurl=`/usr/bin/defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url`
apiuser='apiuser'
apipass=''

# Grab user info from extension attribute for target computer and process.

# Retrieve the computer record data from the JSS API

cmd="curl --silent --user ${apiuser}:${apipass} --request GET ${apiurl}JSSResource/computers/macaddress/${ethernet//:/.}"
hostinfo=$( ${cmd} )

# Reprogram IFS to treat commas as a newline

OIFS=$IFS
IFS=$','

# Now parse the data and get the usernames

adminusers=${hostinfo##*Admin Users\<\/name\>\<value\>}
adminusers=${adminusers%%\<\/value\>*}

# Parse that variable into an array for easier processing

read -a array <<< "$adminusers"

# Set IFS back to normal

IFS=$OIFS

# Loop to check name(s) are present on the mac and process them into the admin group.   

for (( loop=0; loop<=${#array[@]}; loop++ ))
do

# Does specified user exist on the system in /Users? Loop round and if so place in admin group.

 for Account in `ls /Users`
 do

	if [[ $Account == ${array[$loop]} ]];
	then
	   echo "adding "${array[$loop]}" to admin group"
	   dscl . -merge /Groups/admin GroupMembership "${array[$loop]}"
	fi
 done

done

# Finished!

exit 0
