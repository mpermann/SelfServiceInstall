#!/bin/bash

# SelfServiceInstall.bash
# Version: 1.0
# Created: 06-02-2022 by Michael Permann
# Modified:
# Purpose: The script is for installing an app from Self Service. If app is running, the user will be
# notified to save unsaved work and quit the app before proceeding. There will be a countdown timer in
# seconds that will automatically quit the app and start the install if the user doesn't act themselves.
# Parameter 4 is the name of the app to be installed, parameter 5 is the name of the app process,
# parameter 6 is the policy trigger name to install the app, parameter 7 is the countdown timer in
# seconds. The script is relatively basic and can't currently kill more than one process or patch
# more than one app.

APP_NAME=$4
APP_PROCESS_NAME=$5
POLICY_TRIGGER_NAME=$6
TIMER=$7
CURRENT_USER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')
USER_ID=$(/usr/bin/id -u "$CURRENT_USER")
LOGO="/Library/Application Support/HeartlandAEA11/Images/HeartlandLogo@512px.png"
JAMF_HELPER="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
JAMF_BINARY=$(which jamf)
TITLE="Quit Application"
DESCRIPTION="Greetings Heartland Area Education Agency Staff

You are attempting to install $APP_NAME which is already installed and currently running.  Please return to $APP_NAME and save your work and quit the application BEFORE returning here and clicking the \"OK\" button to proceed with the update. Caution: your work could be lost if you don't save it and quit $APP_NAME before clicking the \"OK\" button.

The app will automatically quit and the install start once the countdown timer reaches zero or you click the \"OK\" button.

Thanks! - IT Department"
TITLE2="Install Complete"
DESCRIPTION2="Thank You! 

$APP_NAME has been installed on your computer. You can launch it now if you wish."
BUTTON1="OK"
DEFAULT_BUTTON="1"

# Checking for app deferral plist file. If it exists, delete the file.
if [ -e "/Library/Application Support/HeartlandAEA11/Reporting/${APP_NAME} Deferral.plist" ]
then
    echo "${APP_NAME} Deferral.plist file exists and needs deleted."
    /bin/rm -f "/Library/Application Support/HeartlandAEA11/Reporting/${APP_NAME} Deferral.plist"
else
    echo "${APP_NAME} Deferral.plist does not exist so proceed with install."
fi

echo "App to Install: $APP_NAME  Process Name: $APP_PROCESS_NAME"
echo "Policy Trigger: $POLICY_TRIGGER_NAME  Timer Value: $TIMER"

APP_PROCESS_ID=$(/bin/ps ax | /usr/bin/pgrep -x "$APP_PROCESS_NAME" | /usr/bin/grep -v grep | /usr/bin/awk '{ print $1 }')
echo "$APP_NAME process ID $APP_PROCESS_ID"

if [ -z "$APP_PROCESS_ID" ] # Check whether app is running by testing if string length of process id is zero
then 
    echo "App is NOT running proceed with install"
    "$JAMF_BINARY" policy -event "$POLICY_TRIGGER_NAME"
    "$JAMF_BINARY" recon
    /bin/launchctl asuser "$USER_ID" /usr/bin/sudo -u "$CURRENT_USER" "$JAMF_HELPER" -windowType utility -windowPosition lr -title "$TITLE2" -description "$DESCRIPTION2" -icon "$LOGO" -button1 "$BUTTON1" -defaultButton "$DEFAULT_BUTTON"
    exit 0
else
    echo "App is running so notify user it needs quit"
    DIALOG=$(/bin/launchctl asuser "$USER_ID" /usr/bin/sudo -u "$CURRENT_USER" "$JAMF_HELPER" -button1 "$BUTTON1" -windowType utility -title "$TITLE" -defaultButton "$DEFAULT_BUTTON" -alignCountdown center -description "$DESCRIPTION" -countdown -icon "$LOGO" -windowPosition lr -alignDescription left -timeout "$TIMER")
    echo "$DIALOG"
    if [ "$DIALOG" = "0" ] # Check if the default OK button was clicked or timer expired
    then
        echo "User chose $BUTTON1 or timer expired so proceeding with install"
        APP_PROCESS_ID=$(/bin/ps ax | /usr/bin/pgrep -x "$APP_PROCESS_NAME" | /usr/bin/grep -v grep | /usr/bin/awk '{ print $1 }')
        echo "$APP_NAME process ID $APP_PROCESS_ID"
        if [ -z "$APP_PROCESS_ID" ] # Check whether app is running by testing if string length of process id is zero
        then
            echo "User chose $BUTTON1 and app NOT running so proceed with install"
            "$JAMF_BINARY" policy -event "$POLICY_TRIGGER_NAME"
            "$JAMF_BINARY" recon
            /bin/launchctl asuser "$USER_ID" /usr/bin/sudo -u "$CURRENT_USER" "$JAMF_HELPER" -windowType utility -windowPosition lr -title "$TITLE2" -description "$DESCRIPTION2" -icon "$LOGO" -button1 "$BUTTON1" -defaultButton "$DEFAULT_BUTTON"
            exit 0
        else
            echo "User chose $BUTTON1 and app is running so killing app process ID $APP_PROCESS_ID"
            kill -9 "$APP_PROCESS_ID"
            echo "Proceeding with app install"
            "$JAMF_BINARY" policy -event "$POLICY_TRIGGER_NAME"
            "$JAMF_BINARY" recon
            /bin/launchctl asuser "$USER_ID" /usr/bin/sudo -u "$CURRENT_USER" "$JAMF_HELPER" -windowType utility -windowPosition lr -title "$TITLE2" -description "$DESCRIPTION2" -icon "$LOGO" -button1 "$BUTTON1" -defaultButton "$DEFAULT_BUTTON"
            exit 0
        fi
    fi
fi