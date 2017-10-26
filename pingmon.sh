#!/bin/bash
<< TODO
- Gather IPs
- Establish the command to run
- Set a treshold
- Set a notification medium
- Run the test in a loop
- Keep the threshold in 0
- On a treshold infraction, send a notification and add +1 to the threshold. Keep going
- After the third consecutive failed test, exit the program
TODO

remoteTargets="
# One IP address / hostname per line
"

# How do we want to know what's going on?
# Options:
# - gui
# - cmd (requires $runCmd)
# - stdout
notificationType="stdout"

# Only needed if $notificationType is set to "cmd"
runCmd=""

# $pingCmd current params:
# -q quiet
# -c amount of packets to send
# -b size in bytes of each packet
# -p time in ms to wait till the next packet is sent
# -r retry limit
# -R randomize content of each packet (from the man page: Use to defeat, e.g., link data compression.)

# How many packets will we send?
sentPackets=100

pingCmd="fping -q -c $sentPackets -b 32 -p 50 -r 1 -R"

# How many consecutive errors we'll tolerate before program termination.
exitThreshold=3

# An amount of lost packets below this number is considered an error.
errorThreshold=95

# This is the waiting time inside the loop.
# waitTime is the default. Whenever it's a problem, 
# problemWaitTime will be used.

waitTime=5
problemWaitTime=1

analyzeResults(){
	testResults="$1"
	errorFound=false
	for currentTarget in $remoteTargets; do
		receivedPackets=$(echo "$testResults"|& grep $currentTarget|awk '{ print $5 }'|cut -d/ -f2)
		if [ $receivedPackets -lt $errorThreshold ]; then
			notificationMessage="$notificationMessage Error in $currentTarget: $receivedPackets packets received out of $sentPackets (below $errorThreshold) \n"
			errorFound=true
		fi
	done
	if $errorFound; then
		echo "$notificationMessage"
		return 1
	else
		return 0
	fi
}

sendNotification(){
	notificationMessage=$1
	case $notificationType in
	"gui")
		# As this program must be run as root, we need to
		# a way to connect to X. This might be nice to have
		# a dedicated variable for it.

		export DISPLAY=:0
		zenity --info --text "$notificationMessage" > /dev/null 2>&1 &
		;;
	"cmd")
		# We'll fork the command just in case, we don't want
		# to be affected by a rogue command!
		
		exec $runCmd &
		;;
	"stdout")
		echo "$notificationMessage"
		;;
	*)
		;;
	esac
}

runningTests=0
while [ $runningTests -le $exitThreshold ]; do
	testResults="$($pingCmd $remoteTargets 2>&1)"
	currentStatus="$(analyzeResults "$testResults")"
	if [ $? -eq 0 ]; then
		runningTests=0
		sleep $waitTime
	else
		((runningTests++))
		sendNotification "$currentStatus"
		sleep $problemWaitTime
	fi
done
