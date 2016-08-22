#!/bin/bash -x

# Requirement: Your challenge is to write a piece of automation to run against a remote Ubuntu server.  
#              This should patch the server, install and enable UFW. Finally reboot the server and 
#              display the servers up time.

# Strategy: This task by itself is simple enough to complete using bash. Beyond that, ansible would also
#           be a suitable choice.

# Assumptions: It is assumed that the sudoers file on the target server is configured to allow passwordless 
#              sudo access.

# Enhancements: Though I have hard coded server names etc in this script, a quick and useful enhancement
#               would be to accept the target server as an option or command line arguement. That way 
#               a list of servers can be itteratively passed to this script.
#               The whgile loop that follows the reboot should include code to time out and give up 
#               when waiting for the server to restart.

# Variables which can be overridden if desired
TARGET_HOST=ec2-52-51-107-101.eu-west-1.compute.amazonaws.com
SSH_USER=ubuntu
APT=/usr/bin/apt-get
SSH=/bin/ssh
SHUTDOWN=/sbin/shutdown
REBOOT_TIME_OUT_MINUTES=30
UPTIME=/usr/bin/uptime
PACKAGES_TO_INSTALL="ufw"

# Variables needed internally
TIME_OUT=0
TIME_NOW=0
PACKAGE=""

# Check that the server is online and can be logged into.
${SSH} ${SSH_USER}@${TARGET_HOST} "ls /" >/dev/null 2>&1
[[ $? -ne 0 ]] && echo "ERROR: host ${TARGET_HOST} is inaccessible or cannot be logged into as ${SSH_USER}" && exit 1

# Check that sudoers allows password less command execution.
${SSH} ${SSH_USER}@${TARGET_HOST} "sudo ls" 2>/dev/null
[[ $? -ne 0 ]] && echo "ERROR: user ${SSH_USER} cannot sudo commands on host ${TARGET_HOST}" && exit 1

# Log into TARGET_HOST and update apts package lists. We can assume this will work, but if it fails we 
# can safely ignore the return code since it's likely we will be performing future regular updates as 
# part of a maintenance plan.
echo "Getting latest package lists on server ${TARGET_HOST}."
${SSH} ${SSH_USER}@${TARGET_HOST} "sudo ${APT} update" >/dev/null 2>&1

# Log into TARGET_HOST and upgrade installed packages. Again, ignore the return code.
echo "Upgrading packages on server ${TARGET_HOST}."
${SSH} ${SSH_USER}@${TARGET_HOST} "sudo ${APT} -y upgrade" >/dev/null 2>&1

# Install required packages
for PACKAGE in ${PACKAGES_TO_INSTALL}
do
	echo "Installing package: ${PACKAGE} on server ${TARGET_HOST}"
	${SSH} ${SSH_USER}@${TARGET_HOST} "sudo ${APT} -y install ${PACKAGE}" >/dev/null 2>&1
	[[ $? -ne 0 ]] && "ERROR: problems installing package ${PACKAGE} on server ${TARGET_HOST}" && exit 1
done

# At this point we believe UFW is installed. We could add an additional test to check that it really is.
echo "Checking UFW is installed on server ${TARGET_HOST}"
[[ -z $(${SSH} ${SSH_USER}@${TARGET_HOST} "sudo which ufw" 2>/dev/null) ]] && echo "ERROR: UFW not installed on server ${TARGET_HOST}" && exit 1

# Add an exception too allow ssh connections to the server.
echo "Adding ssh allow rule to ufw on server ${TARGET_HOST}."
${SSH} ${SSH_USER}@${TARGET_HOST} "sudo ufw allow ssh"

# Get the status of the firewall.
if [[ -z $(${SSH} ${SSH_USER}@${TARGET_HOST} "sudo ufw status" 2>/dev/null | grep status | grep -v inactive) ]]
then
	echo "Enabling UFW on server ${TARGET_HOST}."
	${SSH} ${SSH_USER}@${TARGET_HOST} "echo y | sudo ufw enable"
else
	echo "UFW already enabled onserver ${TARGET_HOST}."
fi

# Log into the TARGET_HOST and trigger a reboot. Sleep 10 to ensure the shell does not immediately exit and thus abort the shutdown.
echo "Rebooting server ${TARGET_HOST}."
${SSH} ${SSH_USER}@${TARGET_HOST} "sudo ${SHUTDOWN} -r now && sleep 10" >/dev/null 2>&1

# Get the current time in seconds since the epoch and work out the time we should give up waiting on the reboot.
TIME_OUT=$(( $(date +%s) + (( REBOOT_TIME_OUT_MINUTES * 60 )) ))

# Wait for the server to reboot such that login is possible. Check the server every 10 seconds.
while ! ${SSH} ${SSH_USER}@${TARGET_HOST} "ls /" >/dev/null 2>&1 
do
	sleep 1 # Note: since ssh blocks, we don't really need a sleep in this loop.
	TIME_NOW=$(date +%s)
	(( ${TIME_NOW} > ${TIME_OUT} )) && break
done

# Check if we timed out the reboot. This could have been implemented within the while loop above, though aborting
# within a loop is often considered 'unclean'.
(( ${TIME_NOW} > ${TIME_OUT} )) && echo "ERROR: Server ${TARGET_HOST} did not restart with ${REBOOT_TIME_OUT_MINUTES} minutes" && exit 1

# Log into the system and run the uptime command.
echo "Uptime on server ${TARGET_HOST} is: $(${SSH} ${SSH_USER}@${TARGET_HOST} "${UPTIME}")"

# Exit with a zero return code indicating success.
exit 0

