#!/bin/bash
#
# offline-apt.sh
# Script that helps updating, upgrading and installing SW on an Ubuntu without internet
#

#
# GLOBAL VARIABLES
#

SHORT_NAME=${0##*/}
UPDATE_SIGNATURE_FILE="/tmp/offline-apt-get-update.sig"
UPDATE_DIRECTORY="/tmp/offline-apt-get-update"
UPDATE_PACKAGE_FILE="/tmp/offline-apt-get-update.tar.gz"
UPGRADE_SIGNATURE_FILE="/tmp/offline-apt-get-upgrade.sig"
UPGRADE_DIRECTORY="/tmp/offline-apt-get-upgrade"
UPGRADE_PACKAGE_FILE="/tmp/offline-apt-get-upgrade.tar.gz"
INSTALL_SIGNATURE_FILE="/tmp/offline-apt-get-install.sig"
INSTALL_DIRECTORY="/tmp/offline-apt-get-install"
INSTALL_PACKAGE_FILE="/tmp/offline-apt-get-install.tar.gz"


#
# FUNCTIONS
#

function offline-apt-get-update-first-step () {
    apt-get clean all
    apt-get -qq --print-uris update > $UPDATE_SIGNATURE_FILE
}


function offline-apt-get-update-second-step () {
    mkdir $UPDATE_DIRECTORY
    cd $UPDATE_DIRECTORY
    while read line
    do
        url=`echo $line | cut -d\' -f 2`
        temp-filename=${url##http://}
        filename=${temp-filename//\//_}
        print-and-log "Downloading $url to file $filename..."
        wget -q $url -O $filename || rm -f $filename
    done < $UPDATE_SIGNATURE_FILE
    
    for i in *.bzip2
    do
        bzip2 -q -d $i >/dev/null
    done
    
    tar zcf $UPDATE_PACKAGE_FILE ./*
}


function offline-apt-get-update-third-step () {
    rm -f /var/lib/apt/lists/*
    tar zxf $UPDATE_PACKAGE_FILE -C /var/lib/apt/lists/
    apt-get update --no-download --fix-missing
}


function offline-apt-get-upgrade-first-step () {
    apt-get -qq --print-uris upgrade > $UPGRADE_SIGNATURE_FILE
}


function offline-apt-get-upgrade-second-step () {
    mkdir $UPGRADE_DIRECTORY
    cd $UPGRADE_DIRECTORY
    while read line
    do
        url=`echo $line | cut -d\' -f 2`
        filename=`echo $line | cut -d' ' -f 2`
        md5sum=`echo $line | cut -d' ' -f 4 | sed -e 's/MD5Sum://'`

        print-and-log "Downloading $url..."
        wget -q $url
        if [ $? -eq 0 ]
        then
            echo "Checking md5sum of file $filename..."
            filemd5sum=`md5sum $filename | cut -d' ' -f 1`
            if [ "x$md5sum" != "xfilemd5sum" ]
            then
                print-and-log "md5sum of file $filename is NOT OK! Download it manually!"
            fi
        fi
    done < $UPGRADE_SIGNATURE_FILE
    
    tar zcf $UPGRADE_PACKAGE_FILE ./*
}


function offline-apt-get-upgrade-third-step () {
    rm -f /var/cache/apt/archives/*
    tar xfz $UPGRADE_PACKAGE_FILE -C /var/cache/apt/archives/
    apt-get upgrade --no-download --fix-missing
}


function offline-apt-get-install-first-step () {
    apt-get -qq --print-uris install $PACKAGENAMES > $INSTALL_SIGNATURE_FILE
}


function offline-apt-get-install-second-step () {
    mkdir $INSTALL_DIRECTORY
    cd $INSTALL_DIRECTORY
    while read line
    do
        url=`echo $line | cut -d\' -f 2`
        filename=`echo $line | cut -d' ' -f 2`
        md5sum=`echo $line | cut -d' ' -f 4 | sed -e 's/MD5Sum://'`

        print-and-log "Downloading $url..."
        wget -q $url
        if [ $? -eq 0 ]
        then
            echo "Checking md5sum of file $filename..."
            filemd5sum=`md5sum $filename | cut -d' ' -f 1`
            if [ "x$md5sum" != "xfilemd5sum" ]
            then
                print-and-log "md5sum of file $filename is NOT OK! Download it manually!"
            fi
        fi
    done < $INSTALL_SIGNATURE_FILE
    
    tar zcf $INSTALL_PACKAGE_FILE ./*
}


function offline-apt-get-install-third-step () {
    tar xfz $INSTALL_PACKAGE_FILE -C /var/cache/apt/archives/
    apt-get install --no-download --fix-missing $PACKAGENAMES
}


function ctrl-c-handler () {
    print-and-log "\n$SHORT_NAME is now exiting."
    print-and-log "Cleaning up working files..."
}


function exit-with-error () {
    print-and-log "ERROR: $1"
    exit 1
}


function exit-with-noerror () {
    print-and-log "$1"
    exit 0
}


function print-and-log () {
    echo -e "$1"
    logger -t [OFFLINE-APT] "${1//\\n/ }"
}


function show_usage () {
    cat << END_USAGE
Usage: $SHORT_NAME option [package1 [package2 ...]] step

Options
  -d    Updates apt thus refreshes the apt cache to have the latest references
  -g    Upgrades the system with the latest version of the installed packages
  -i    Installs a package or packages
  -h    Prints this usage info

Steps
  -1    First step on the offline computer which creates the signature file
  -2    Second step on the online computer. Downloads packages according to the signature file of the previous step
  -3    Third step on the offline computer which installs the downloaded packages
END_USAGE

}


#
# MAIN
#

# Setup Ctrl-C handling

trap ctrl-c-handler INT


# Check whether we are root

if [ `id -u` -ne 0 ]
then
	exit-with-error "You must be root to execute this script. Exiting..."
fi


# Check command line parameters

while getopts ":i:dg123h" MYOPTION
do
	case $MYOPTION in
	i )
        if [ $# -lt 3 ]
		then
			exit-with-error "Wrong number of arguments. Exiting..."
		fi
        OPERATION="INSTALL"
        PACKAGENAMES=$*
    ;;
	d ) OPERATION="UPDATE" ;;
    g ) OPERATION="UPGRADE" ;;
	1 ) STEP="FIRST" ;;
	2 ) STEP="SECOND" ;;
	3 ) STEP="THIRD" ;;
	h )
		if [ $# -ne 1 ]
		then
			exit-with-error "Wrong number of arguments. Exiting..."
		fi
		show_usage
		exit-with-noerror
	;;
	\? ) exit-with-error "Invalid argument: -$OPTARG. Exiting..." ;;
	\: ) exit-with-error "Argument is missing for -$OPTARG. Exiting..." ;;
	esac
done
shift $(($OPTIND-1))

if [ "x$*" != "x" ]
then
	exit-with-error "Unknown option/parameter: $*. Exiting..."
fi

if [ "x${OPERATION[*]}" == "x" ]
then
	exit-with-error "Missing operation. Exiting..."
fi

if [ "x$STEP" == "x" ]
then
	exit-with-error "Missing step. Exiting..."
fi

exit 0
 

