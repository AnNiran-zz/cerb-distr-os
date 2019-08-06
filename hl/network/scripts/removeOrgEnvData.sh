#!/bin/bash

org=$1

function removeEnvVariable() {
	varName=$1
	currentValue=$2

	if [ -z "$currentValue" ]; then
		echo "$varName is not present"
	else
		unset $varName
		sed -i -e "/${varName}/d" .env
		echo "${varName} deleted"
	fi

	source .env
}

ARCH=$(uname -s | grep Darwin)
if [ "$ARCH" == "Darwin" ]; then
	OPTS="-it"
else
	OPTS="-i"
fi

CURRENT_DIR=$PWD

ORG_CONFIG_FILE=external-orgs/${org}-data.json

if [ ! -f "$ORG_CONFIG_FILE" ]; then
	echo
	echo "ERROR: $ORG_CONFIG_FILE file not found. Cannot proceed with parsing organization configuration data"
	exit 
fi

source .env
source ~/.profile

orgLabelValue=$(jq -r '.label' $ORG_CONFIG_FILE)
orgLabelValueStripped=$(echo $orgLabelValue | sed 's/"//g')
orgLabelVar="${orgLabelValueStripped^^}_ORG_LABEL"

# remove organization label
removeEnvVariable "${orgLabelValueStripped^^}_ORG_LABEL" "${!orgLabelVar}"
 
orgContainers=$(jq -r '.containers[]' $ORG_CONFIG_FILE)

for orgContainer in $(echo "${orgContainers}" | jq -r '. | @base64'); do
	_jq(){
		peerNameValue=$(echo "\"$(echo ${orgContainer} | base64 --decode | jq -r ${1})\"")
		peerNameValueStripped=$(echo $peerNameValue | sed 's/"//g')
		peerNameVar="${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_NAME"

		peerContainerVar="${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_CONTAINER"

		peerHostVar="${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_HOST"

		peerUsernameVar="${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_USERNAME"

		peerPasswordVar="${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_PASSWORD"

		peerPathVar="${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_PATH"

		source .env

		# remove name
		removeEnvVariable "${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_NAME" "${!peerNameVar}"

		# remove container
		removeEnvVariable "${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_CONTAINER" "${!peerContainerVar}"

		# remove host
		removeEnvVariable "${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_HOST" "${!peerHostVar}"

		# remove username
		removeEnvVariable "${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_USERNAME" "${!peerUsernameVar}"

		# remove password
		removeEnvVariable "${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_PASSWORD" "${!peerPasswordVar}"

		# remove path
		removeEnvVariable "${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_PATH" "${!peerPathVar}"

		source .env
	}
	echo $(_jq '.name')
done

echo "Organization ${org^} environment data successfully removed from Cerberus network"


