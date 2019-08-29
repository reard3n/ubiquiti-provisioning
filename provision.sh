#!/bin/bash

rm /tmp/ident
touch /tmp/ident
chmod 700 /tmp/ident

FIRMWARE=WA.v8.6.2.41239.190822.1633.bin
REMOTEIP=192.168.1.20
PASSWORD=ubnt
SSHOPTS="-q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
STEP=1
STEPS=3

# do we need to download the latest firmware?
FWDLPATH=`curl -s -H "Accept: text/json" -H "x-requested-with: XMLHttpRequest" https://www.ui.com/download/?group=litebeam-ac-gen2 | jq | grep file_path | tail -1 | awk -F":" '{print $2}' | awk -F'"' '{print $2}'`
FWNAME=`echo $FWDLPATH | awk -F"/" '{print $NF}'`

if [ $FWNAME != $FIRMWARE ]
then
	echo "You need to download the latest firmware version, $FWNAME"
	exit
fi

function waitForDevice {
	# wait for the unit to initiall boot
	ONLINE=0
	while [ $ONLINE -lt 1 ]
	do
		echo "[Step $STEP of $STEPS]    Unit is still offline. Waiting for it to come up."
		ONLINE=`ping -c1 -w2 192.168.1.20 2>&1 | grep -c "1 packets received"`
		sleep 1
	done
}


# wait for the unit to initially boot
waitForDevice

echo "[Step 1 of 3]    Unit is online. Beginning firmware update."
sleep 20

# update the firmware
sshpass -p$PASSWORD scp $SSHOPTS $FIRMWARE ubnt@192.168.1.20:/tmp/fwupdate.bin 2>&1 > /dev/null
sshpass -p$PASSWORD ssh $SSHOPTS ubnt@$REMOTEIP "/sbin/fwupdate -m" 2>&1 > /dev/null
STEP=2

# wait for the unit to reboot
sleep 10
waitForDevice

echo "[Step $STEP of $STEPS]    Unit is back online, completing configuration."

sleep 10

echo "[Step $STEP of $STEPS]    Uploading Centre WISP configuration."
sshpass -p$PASSWORD scp $SSHOPTS running.cfg ubnt@$REMOTEIP:/tmp/system.cfg 2>&1 > /dev/null
sshpass -p$PASSWORD ssh $SSHOPTS ubnt@$REMOTEIP "/sbin/cfgmtd -p /etc/ -w && /bin/sleep 5 && /usr/etc/rc.d/rc.softrestart save" 2>&1 > /dev/null
sleep 10
STEP=3


# now wait for that "soft" restart to complete
echo "[Step $STEP of $STEPS]    Waiting for unit to complete accepting new config."
waitForDevice
echo ""
echo "PROVISIONING IS COMPLETE"
