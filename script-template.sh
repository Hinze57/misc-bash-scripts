#!/bin/bash
#
############################################
# File: script_name.sh
#
# Purpose: This is a script template ....
#          
# Modification History (ddMonYYYY): 
#   01Jun2014 - Initial build/dev @KPH
#   15Feb2017 - Added few variables & functions as examples @KPH
#
# ToDo:
#   -crap we hope to implement
#
############################################

######################
# Variable Section
######################
## script_version
version=1.0.0
## Change as suits site/location
# set hostName var to what is configured on the system
hostName=$(echo $(hostname -s) | tr "[:lower:]" "[:upper:]")
# point configFile to file containing variables/functions you want to import/read in
configFile=$(dirname $0)/local.conf
# source/import the above configFile
source ${configFile}

## Shouldn't need to change anything below this line
# set up tmp dir for working files 
tmpDir=$(mktemp -d)
# cleanup on exit
trap "{ cleanUp ; exit 255; }" EXIT

######################
# Functions
######################
## print usage
usage() {
    cat <<-usageEOF
Usage:
   sudo $0

usageEOF
    exit 1
}

## cleanup routine to close socket & rm tmp files
cleanUp() {
    # add any kill/shutdown cmds here needed on script exit
    # rm tmpDir
    rm -fr $tmpDir
}


######################
# Main
######################


exit 0
