#!/bin/bash
#
############################################
# File: 
#
# Purpose: Script to gen custom RHEL ISO
#          
# Modification History (ddMonYYYY): 
#   01Jun2014 - Initial build/dev @KPH
#   15Feb2017 - Added few variables & functions as examples @KPH
#   09Mar2017 - Cleanup & readability updates
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
# set to locations matching your build_tree
gitRepoDir=/home/kevinh/git/projects   # repo where I store kickstarts, etc.
buildDIR=/var/data/rhel                # main working dir
isoDIR=/data/iso                       # where to write iso-image to
# set hostName var to what is configured on the system && uppercase it
hostName=$(echo $(hostname -s) | tr "[:lower:]" "[:upper:]")
# point configFile to file containing variables/functions you want to import/read in
configFile=$(dirname $0)/local.conf
# source/import the above configFile
[[ -f ${configFile} ]] && source ${configFile}

## Shouldn't need to change anything below this line
# set up tmp dir for working files 
tmpDir=$(mktemp -d)
# cleanup on exit
trap "{ cleanUp ; exit 255; }" EXIT

#####################
## info on building hybrid iso (BIOS/UEFI):
## http://fedoraproject.org/wiki/User:Pjones/BootableCDsForBIOSAndUEFI
## https://access.redhat.com/discussions/762253
#####################

######################
# Functions
######################
## print usage
Usage() {
    cat <<-usageEOF
$0 [-5 | -6] 
    -5  builds a Custom RHEL 5 ISO image
    -6  builds a Custom RHEL 6 Server ISO image

usageEOF
    exit 1
}

## function to burn the RHEL5 ISO
genRhel5Iso() {
    pushd ${isoBuildDIR} >/dev/null
    echo "Working Dir set to: $(pwd) "
    genisoimage -o ${isoDIR}/${isoImgNAME} \
        -A "${isoVolNAME}_$(date +%m%d%Y)" \
        -V "${isoVolNAME}" \
        -J -R -v -d -N -hide-rr-moved \
        -allow-leading-dots \
        -joliet-long \
        -uid 0 -gid 0 \
        -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -no-emul-boot -boot-load-size 4 \
        -boot-info-table \
        .
}

## function to burn the RHEL6 ISO
genRhel6Iso() {
    ## command below is for a bootable (el torrito) ISO / dual Legacy & UEFI
    #important to run genisoimage cmd from buildDir when building UEFI RHEL 6 image
    pushd ${isoBuildDIR} >/dev/null
    echo "Working Dir set to: $(pwd) "
    genisoimage -o ${isoDIR}/${isoImgNAME} \
        -A "${isoVolNAME}_$(date +%m%d%Y)" \
        -V "${isoVolNAME}" \
        -J -R -v -d -N -hide-rr-moved \
        -joliet-long \
        -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -no-emul-boot -boot-load-size 4 \
        -boot-info-table -eltorito-alt-boot \
        -e images/efiboot.img -no-emul-boot \
        .
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
# test if not passed any args && call Usage func()
if [ $# -eq 0 ]; then Usage; fi

# use while loop && case to grab args && assign paths correctly
while getopts 56 OPT
do
	case $OPT in
	    5) #RHEL 5 
		echo -n "Select Server or Workstation [S/W]: "
		read ANS
		if [[ ${ANS} == [Ss] ]]; then
		    echo "Preparing to build a Server ISO ... "
		    isoBuildDIR=${buildDIR}/custom-rhel5-server
		    isoImgNAME=rhel-5-server-custom.iso
		    isoVolNAME=RHEL-5-Server-Custom
		    genISOfunc=genRhel5Iso
		    repoDir=${gitRepoDir}/kickstart/rhel5/server
		elif [[ ${ANS} == [Ww] ]]; then
		    echo "Prepping to build a Workstation ISO ... "
		    isoBuildDIR=${buildDIR}/custom-rhel5-wkstn
		    isoImgNAME=rhel-5-wkstn-custom.iso
		    isoVolNAME=RHEL-5-Wkstn-Custom
		    genISOfunc=genRhel5Iso
		    repoDir=${gitRepoDir}/kickstart/rhel5/wkstn
		else
		    echo "What the HAY?!" && exit 1
		fi
		;;
        6) #set isoDIR to RHEL6 Custom build location
            isoBuildDIR=${buildDIR}/custom-rhel6-server
            isoImgNAME=rhel-6-server-custom.iso
            isoVolNAME=RHEL-6-Server-Custom
            genISOfunc=genRhel6Iso
            repoDir=${gitRepoDir}/kickstart/rhel6
		;;
		*) Usage
		;;
	esac
done

# sync git repo crap to ensure we're up-to-date prior to burn
echo "==========================="
echo "Syncing files ..."
[ -d ${repoDir}/isolinux/ ] && rsync -ahvP ${repoDir}/isolinux/ ${isoBuildDIR}/isolinux/
[ -d ${repoDir}/EFI ] && rsync -ahvP ${repoDir}/EFI/ ${isoBuildDIR}/EFI/
echo "Done "
sleep 1
echo "==========================="
isoVer=$(head -1 ${isoBuildDIR}/VERSION) # Version, read from file
#echo option to update version
echo "ISO image version is currently set to: ${isoVer}"
echo -n "Did you want to update the version? [y/n]: "
read ANS
if [[ "$ANS" == "y" ]]; then
    vi ${isoBuildDIR}/VERSION
    isoVer=$(head -1 ${isoBuildDIR}/VERSION) # re-read version
fi

# cd into $isoBuildDIR first since boot catalog MUST be relative to
#  mkisofs/genisoimage cmd
cd ${isoBuildDIR}

#call appropriate genISO function
${genISOfunc}

if [[ $? -eq 0 ]]; then
    echo "================================================================= "
    echo "ISO image: ${isoImgNAME} successfully created "
    echo "To burn this image to a DVD, execute the following: "
    echo "dvdrecord -v -eject speed=0 dev=/dev/sr0 ${isoDIR}/${isoImgNAME} "
    echo "================================================================= "
else
    echo "Houston, we have a problem ... "
    echo "Could not create the ISO image! "
fi

######################
exit 0

