#!/bin/bash

. scripts/cerberus/helpFunctions.sh

ARCH=$(uname -s | grep Darwin)
if [ "$ARCH" == "Darwin" ]; then
        OPTS="-it"
else
        OPTS="-i"
fi

CURRENT_DIR=$PWD

# read configuration file
cerberusOrgConfigFile=cerberus-config/org/org-data.json

if [ ! -f "$cerberusOrgConfigFile" ]; then
        echo
        echo "ERROR: $cerberusOrgConfigFile file not found. Cannot proceed with parsing new orgation configuration"
        exit 1
fi

source .env
source ~/.profile

myHostValue=$(jq -r '.myHost' $cerberusOrgConfigFile)
resultHost=$?

if [ $resultHost -ne 0 ]; then
	echo "ERROR: File format for $cerberusOrgConfigFile does not match expected"
	exit 1
fi

myHostValueStripped=$(echo $myHostValue | sed 's/"//g')

# cerberusorg containers
cerberusOrgRemotePeerse=$(jq -r '.runningRemotely[]' $cerberusOrgConfigFile)
result=$?

if [ $result -ne 0 ]; then
	echo "ERROR: File format for $cerberusOrgConfigFile does not match expected"
	exit 1
fi

for peer in $(echo "${cerberusOrgRemotePeers}" | jq -r '. | @base64'); do
	_jq(){
		peerNameValue=$(echo "\"$(echo ${peer} | base64 --decode | jq -r ${1})\"")
		peerNameValueStripped=$(echo $peerNameValue | sed 's/"//g')
		peerNameVar="CERBERUSORG_${peerNameValueStripped^^}_NAME"

		peerContainerValue=$(echo "\"$(echo ${peer} | base64 --decode | jq -r ${2})\"")
		peerContainerValueStripped=$(echo $peerContainerValue | sed 's/"//g')
		peerContainerVar="CERBERUSORG_${peerNameValueStripped^^}_CONTAINER"

		peerHostValue=$(echo "\"$(echo ${peer} | base64 --decode | jq -r ${3})\"")
                peerHostValueStripped=$(echo $peerHostValue | sed 's/"//g')
                peerHostVar="CERBERUSORG_${peerNameValueStripped^^}_HOST"
		
		peerUsernameValue=$(echo "\"$(echo ${peer} | base64 --decode | jq -r ${4})\"")
		peerUsernameValueStripped=$(echo $peerUsernameValue | sed 's/"//g')
		peerUsernameVar="CERBERUSORG_${peerNameValueStripped^^}_USERNAME"

		peerPasswordValue=$(echo "\"$(echo ${peer} | base64 --decode | jq -r ${5})\"")
		peerPasswordValueStripped=$(echo $peerPasswordValue | sed 's/"//g')
		peerPasswordVar="CERBERUSORG_${peerNameValueStripped^^}_PASSWORD"
		
		peerPathValue=$(echo "\"$(echo ${peer} | base64 --decode | jq -r ${6})\"")
		peerPathValueStripped=$(echo $peerPathValue | sed 's/"//g')
		peerPathVar="CERBERUSORG_${peerNameValueStripped^^}_PATH"

		# add peer name
		addEnvVariable $peerNameValueStripped "CERBERUSORG_${peerNameValueStripped^^}_NAME" "${peerNameVar}"

		# add peer container
		addEnvVariable $peerContainerValueStripped "CERBERUSORG_${peerNameValueStripped^^}_CONTAINER" "${!peerContainerVar}"

		# add peer host
		addEnvVariable $peerHostValueStripped "CERBERUSORG_${peerNameValueStripped^^}_HOST" "${!peerHostVar}"

		# add peer username
		addEnvVariable $peerUsernameValueStripped "CERBERUSORG_${peerNameValueStripped^^}_USERNAME" "${!peerUsernameVar}"

		# add peer password
		addEnvVariable $peerPasswordValueStripped "CERBERUSORG_${peerNameValueStripped^^}_PASSWORD" "${!peerPasswordVar}"

		# add peer path
		addEnvVariable $peerPathValueStripped "CERBERUSORG_${peerNameValueStripped^^}_PATH" "${!peerPathVar}"

		source .env
	}
	echo $(_jq '.name' '.container' '.host' '.username' '.password' '.path')
done

echo
echo "CerberusOrg external peers successfully added to local environment"
echo

