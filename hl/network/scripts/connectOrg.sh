#!/bin/bash
. scripts/utils.sh

function removeExternalOrgArtifacts() {
	orgName=$1
	CURRENT_DIR=$PWD
	cd external-orgs/

	if [ ! -d ${orgName}-artifacts ]; then
		echo "${orgName}-artifacts/ folder does not exist"
		exit 1
	fi

	source .env
	rm ${orgName}-artifacts/*.yaml ${orgName}-artifacts/*.json

	echo "${orgName} artifacts have been removed from ${orgName}-artifacts/ folder"
}
