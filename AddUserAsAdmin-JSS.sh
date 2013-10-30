#!/bin/bash

# Script to grab the localadmins file and apply changes to a target computer at logon.

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

macname=$( scutil --get ComputerName | awk '{print substr($0,length($0)-3,4)}' )
ethernet=$(ifconfig en0|grep ether|awk '{ print $2; }')
apiurl='$( /usr/bin/defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url )'
apiuser='apiuser'
apipass='Y8Lg82WBoRBEayg3nLVx3KKnK'

# Grab user info from extension attribute for target computer and process.

# Retrieve the computer record data from the JSS API

cmd="curl --silent --user ${apiuser}:${apipass} --request GET ${apiurl}/JSSResource/computers/macaddress/${ethernet//:/.}"
hostinfo=$( ${cmd} )

# Reprogram IFS to treat commas as a newline

OIFS=$IFS
IFS=$','

# Now parse the data and get the comma separated usernames

adminusers=${hostinfo##*Admin Users\<\/name\>\<value\>}
adminusers=${adminusers%%\<\/value\>*}

# Read admin rights file line by line and process. -r used to make sure \ char is processed.

cat $adminusers | while read -r adminline
do

# Because the file contains bash reserved characters, we must remove them before processing.
# This will cause the script to ignore the line totally.

line=$( echo ${adminline//[*]/} )

# Grab the name of the computer from the current line of the file

   compname=$( echo "${line}" | cut -d : -f 1 | awk '{print substr($0,length($0)-3,4)}' )
   
# Find out how many users are listed by counting the commas
   
   usercount=$( echo $((`echo ${line} | sed 's/[^,]//g' | wc -m`-1)) )

# Does the current computer name match the one in the file?

   if [ "$macname" = "$compname" ];
   then

# Loop to check name(s) are present on the mac and process them into the admin group.   

      for (( loop=0; loop<=usercount; loop++ ))
      do

		 field=$(($loop + 1))

# Cut out the 4th field, select the user depending on the loop by cutting using , as a delimiter
# Then strip off the artslocal\ and finally remove Windows horrible \r that it appends to end of every line

         username=$( echo "${line}" | cut -d : -f 4 | cut -d "," -f ${field} | cut -c11- | sed "s/$(printf '\r')\$//" )
         
# Does specified user exist on the system in /Users? Loop round and if so place in admin group.
      
         for Account in `ls /Users`
         do

            if [[ $Account == $username ]];
            then
               echo "adding "$username" to admin group"
               dscl . -merge /Groups/admin GroupMembership "$username"
            fi
         done
      done
   fi
done

# Clean up and finish

IFS=$OIFS
rm /var/tmp/localadmins.txt
exit 0
