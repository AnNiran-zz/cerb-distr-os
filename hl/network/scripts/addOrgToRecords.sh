#!/bin/bash
orgName=$1
channelsList=$2

ARCH=$(uname -s | grep Darwin)
if [ "$ARCH" == "Darwin" ]; then
        OPTS="-it"
else
        OPTS="-i"
fi

# add new organization to json channel records
CURRENT_DIR=$PWD

ORG_CONFIG_FILE="external-orgs/${orgName}-data.json"
if [ ! -f "$ORG_CONFIG_FILE" ]; then
	echo
	echo "ERROR: external-orgs/$orgName-data.json not found. Cannot proceed with parsing organization data."
	echo "Add configuration file inside external-orgs/ directory and run ./cerberusntw.sh record -n sipher in order to finish the configuration"
	exit 1
fi

source .env
source ~/.profile

orgLabelValue=$(jq -r '.label' $ORG_CONFIG_FILE)
result=$?

if [ $result -ne 0 ]; then
        echo "ERROR: File format for $ORG_CONFIG_FILE does no match expected"
        exit 1
fi

orgLabelValueStripped=$(echo $orgLabelValue | sed 's/"//g')

orgNameValue=$(jq -r '.name' $ORG_CONFIG_FILE)
result=$?
if [ $result -ne 0 ]; then
        echo "ERROR: File format for $ORG_CONFIG_FILE does no match expected"
        exit 1
fi

orgNameValueStripped=$(echo $orgNameValue | sed 's/"//g')

orgMspLabelValue=$(jq -r '.msp' $ORG_CONFIG_FILE)
result=$?

if [ $result -ne 0 ]; then
        echo "ERROR: File format for $ORG_CONFIG_FILE does no match expected"
        exit 1
fi

orgMspValueStripped=$(echo $orgMspLabelValue | sed 's/"//g')

orgContainers=$(jq -r '.containers[]' $ORG_CONFIG_FILE)
result=$?

if [ $result -ne 0 ]; then
        echo "ERROR: File format for $ORG_CONFIG_FILE does no match expected"
        exit 1
fi
	
cd network-config/

# update current records
jq ".$orgLabelValueStripped.label = \"$orgLabelValueStripped\"" organizations-data.json
jq ".$orgLabelValueStripped.msp = \"$orgMspValueStripped\"" organizations-data.json
jq ".$orgLabelValueStripped.name = \"$orgNameValueStripped\"" organizations-data.json

exit 0
# check if organization exists in surrent records
currentOrganizationsRecord=organizations-data.json
touch organizations-data-updated.json
#echo "{\"organizations\":[" >> organizations-data-updated.json

currentOrganizations=$(jq -r '.organizations[]' organizations-data.json)

# check if records with same label exist and delte them
for organization in $(echo "${currentOrganizations}" | jq -r '.org | @base64'); do
	_jq(){
		label=$(echo $(echo ${organization} | base64 --decode | jq -r ${1}))
		name=$(echo $(echo ${organization} | base64 --decode | jq -r ${2}))
		msp=$(echo $(echo ${organization} | base64 --decode | jq -r ${3}))
		channels=$(echo $(echo ${organization} | base64 --decode | jq -r ${4}))
		
		if [ ${label} == ${orgLabelValueStripped} ]; then
			# do not add old record
			echo "Old records with same label exist. Updating"
			recordToUpdate=$(echo $organization | base64 --decode)
			echo $recordToUpdate
		

		else
			# add rest of the records to the updated file
			echo "{\"org\":{\"label\":\"$label\",\"name\":\"$name\",\"msp\":\"$msp\",\"channels\":\"$channels\"}}," >> organizations-data-updated.json			
		fi
	}
	echo $(_jq '.label' '.name' '.msp' '.channels')
done

# get channels
echo $channelsList

# add new records
echo "{\"org\":{\"label\":\"$orgLabelValueStripped\",\"name\":\"$orgNameValueStripped\",\"msp\":\"$orgMspValueStripped\",\"channels\":\"$channels\"}}" >> organizations-data-updated.json

echo "]}" >> organizations-data-updated.json
####


#jq '.organizations[.organizations| length] |= . + {"org":{"label":"'$orgLabelValueStripped'","msp":"'$orgMspLabelValueStripped'","channels":[]}}' org-data.json >org-data-updated.json

#rm org-data.json
#mv org-data-updated.json org-data.json
	
#echo "========= ${orgLabelValueStripped^^} added to Cerberus Network organizations records ========="
