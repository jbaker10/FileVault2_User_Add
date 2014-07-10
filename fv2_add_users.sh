#!/usr/bin/env bash


####################################################################
##
## Script Name: fv2_add_users.sh
## Written By: Jeremiah Baker
## Last Edit Date: 01/27/2014
## Script Description: This script will try to add users to be authorized pre-boot users when FV2 is enabled.
##
##
## This script uses the application called CocoaDialog, which gives shell scripts a GUI interface, so as to allow all users to be able to interact with the script. This can be found at http://mstratman.github.io/cocoadialog/
####################################################################

#### Things to add in the future:

#### 1) Take out the admin cleartext credentials

####################################################################
##
## Changelog:
##
## Date: 01/27/2014
## Action: Added conditional statement in the beginning because users were being given ERROR 2 repeatedly even after being authorized
##
##
##
####################################################################



######## Declare Global Variables Below

## Checks OS version
version=`sw_vers | grep ProductVersion | cut -f 2`

## Sets the user to the login name as opposed to using whoami as this gets messed up when running a sudo command, it sees the user as root
user=`logname`

## Sets the authorization status for the list of FV users
authorizedStatus=`sudo /usr/bin/fdesetup list`

# create a named pipe
rm -f /tmp/hpipe
mkfifo /tmp/hpipe

## Changes the directory to the current directory holding the cocoaDialog app, which I like to store out of the way of the normal user's /Applications folder, as most users won't need to use it
CD=/Library/Application\ Support/CocoaDialog.app/Contents/MacOS/CocoaDialog
echo $CD

######################


## This script requires being run by root, so before doing anything, we need to make sure this is true
checkIfRoot() {
	## Make sure only root can run the script
	if [[ $EUID -ne 0 ]]; then
	   echo "\nThis script must be run as root. You shall not pass...\n" 1>&2
	   sleep 2;
	   exit 1;
	else
		echo "\nYOU ARE ROOT!! You may enter...\n"
		sleep 2;
	fi
}
checkIfRoot;


## sets 'i'  for the while loop
i=0

## The checkPasswords functions is a while loop that will run a max of 3 times if necessary. Each time it will ask the user for their password twice, and then compare the strings to make sure they match. If they do not match, it will display an error and restart the loop until it has run 3 times at which point it will tell the user to contact their IT department
checkPasswords(){
    while [ $i -lt 3 ]; 
        do

            ## It was necessary to set the password variable twice for each password entered because the first one uses the built in cocoaDialog flags to take in the passwords, and the second one strips an unwanted space out that is added by default in the cocoaDialog variable

            getPwd1=`$CD secure-standard-inputbox --title "Enter Password" --informative-text "Please enter your Network password below to allow the "$user" access to this encrypted disk:" --no-cancel --float`
            pwd1=`echo $getPwd1 | awk '{print $NF}'`


            getPwd2=`$CD secure-standard-inputbox --title "Re-enter Password" --informative-text "Please enter your password again for verification:" --no-cancel --float`
            pwd2=`echo $getPwd2 | awk '{print $NF}'`


            ## This checks to see if the strings DO NOT match, if they don't, it adds 1 to the counter (i) and then displays an error and calls the function again to have the user re-enter their password again

            if [ $pwd2 != $pwd1 ]; then
                let i=i+1;
                echo $i
                if [ $i == 1 ];
                then
                    $CD ok-msgbox --title "" --text "Your passwords do not match" --informative-text "You will have two more attempts" --float --no-cancel
                elif [ $i == 2 ];
                then
                    $CD ok-msgbox --title "" --text "Your passwords do not match" --informative-text "You will have one more attempt" --float --no-cancel

                elif [ $i == 3 ];
                then
                    $CD ok-msgbox --title "" --text "Your passwords do not match" --informative-text "Please screenshot this error (ERROR 1) and contact your IT Dept at <ENTER IT CONTACNT INFO>" --float --no-cancel
                fi
                checkPasswords;

            ## If the statement is false, as in the password strings DO match, it will then check the OS version. This is necessary due to a slight change in the fdesetup add user command in Mavericks (10.9) vs. 10.8 and 10.7
            else
                if [[ $version == *10.9* ]];
                then
                    echo "Version is Mav"
                    enableUserMav;
                    checkSuccess;
                    exit 0;
                elif [[ $version == *10.8* ]];
                then
                    echo "Version is ML"
                    enableUserML;
                    checkSuccess;
                    exit 0;
                fi
            fi
        done
}

## These functions are specific to the OS version as mentioned in the note above
enableUserMav(){
expect << DONE

    ## Run fdesetup command to add user after Filevault has already been enabled
    spawn sudo /usr/bin/fdesetup add -usertoadd $user
    
    expect "Enter a password for '/', or the recovery key:"
    send -- "P@ssword\r";

    expect "Enter the password for the added user '$user':"
    send -- "$pwd1\r";

sleep 10
DONE
}

enableUserML(){
expect << DONE

    ## Run fdesetup command to add user after Filevault has already been enabled
    spawn sudo /usr/bin/fdesetup add -usertoadd $user

    expect "Enter the primary user name:"

    send -- "$user\r";

    expect "Enter the password for the user '$user':"
    send -- "$pwd1\r";

    expect "Enter the password for the added user '$user':"
    send -- "$pwd1\r";


sleep 10
DONE
}


## This function checks to see if the user was added correctly. It runs the command in fdesetup to see the list of users that have been authorized, and then checks to see if the string matching the 'logname' is in that command output. It also is in a while loop that will run a total of 3 times and functions essentially the same as the checkPasswords() function above. The primary purpose was to make sure the user did not get stuck in a loop of not getting added, as well as if your company has a max login attempt number set, if you have a lockout policy, the user may get locked out by trying to authenticate too many times.
j=0
checkSuccess(){
    while [ $j -lt 3 ];
        do
            list=`sudo /usr/bin/fdesetup list`

            if [[ $list == *$user* ]];
            then
                $CD ok-msgbox --title "" --text "Success" --informative-text "$username has been successfully added to the list of authorized pre-boot users" --float
                exit 0;
            else
                let j=j+1;
                if [ $j == 1 ]; then
                    $CD ok-msgbox --title "" --text "Failed: Could not authorize user" --informative-text "Please ensure that you are entering your Network Login Credentials. You have two more attempts" --float --no-cancel
                    checkPasswords;
                elif [ $j == 2 ]; then
                    $CD ok-msgbox --title "" --text "Failed: Could not authorize user" --informative-text "Please ensure that you are entering your Network Login Credentials. You have one more attempt" --float --no-cancel
                    checkPasswords;
                elif [ $j == 3 ]; then
                    $CD ok-msgbox --title "" --text "Failed: Could not authorize user" --informative-text "Please screenshot this error (ERROR 2) and contact your IT Dept at <ENTER IT CONTACNT INFO>" --float --no-cancel
                    exit 1;
                fi
            fi
        done
}

## This will check to see if the user was already added to the authorized FV users list, to ensure it does not try to readd a person continuously BEFORE even trying to add them, whereas the function checkSuccess() is to check AFTER they have been assumingly been added

if [[ $authorizedStatus == *$user* ]];
then
    echo "TRUE, $user has already been authorized"
    exit 0;
else
    echo "FALSE, $user has NOT been authorized"
    ## This starts the whole process by calling the checkPasswords() function at the top.
    checkPasswords;
fi;
exit 0;