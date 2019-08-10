#!/bin/bash

function addEnvVariable() {
	newValue=$1
	varName=$2
	currentValue=$3

	if [ -z "$currentValue" ]; then
		echo "${varName}=${newValue}">>.env
		echo "### $varName obtained"
	elif [ "$currentValue" != "$newValue" ]; then
		unset $varName
		sed -i -e "/${varName}/d" .env

		echo "${varName}=${newValue}">>.env
		echo "### ${varName} value updated"
	else
		echo "${varName} already set"
		echo ""
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

ORG_CONFIG_FILE=$1
 
if [ ! -f "$ORG_CONFIG_FILE" ]; then
	echo
	echo "ERROR: $ORG_CONFIG_FILE file not found. Cannot proceed with parsing new orgation configuration"
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
orgLabelVar="${orgLabelValueStripped^^}_ORG_LABEL"

# add organization label
addEnvVariable $orgLabelValueStripped "${orgLabelValueStripped^^}_ORG_LABEL" "${!orgLabelVar}"

orgMspLabelValue=$(jq -r 'msp' $ORG_CONFIG_FILE)
result=$?

if [ $result -ne 0 ]; then
        echo "ERROR: File format for $ORG_CONFIG_FILE does no match expected"
        exit 1
fi

orgMspLabelValueStripped=$(echo $orgMspLabelValue | sed 's/"//g')
orgMspLabelVar="${orgLabelValueStripped^^}_ORG_MSP"

# add organization msp
addEnvVariable $orgMspLabelValueStripped "${orgLabelValueStripped^^}_ORG_MSP" "${!orgMspLabelVar}"

orgContainers=$(jq -r '.containers[]' $ORG_CONFIG_FILE)
result=$?

if [ $result -ne 0 ]; then
        echo "ERROR: File format for $ORG_CONFIG_FILE does no match expected"
        exit 1
fi

for orgContainer in $(echo "${orgContainers}" | jq -r '. | @base64'); do
	_jq(){
		peerNameValue=$(echo "\"$(echo ${orgContainer} | base64 --decode | jq -r ${1})\"")
		peerNameValueStripped=$(echo $peerNameValue | sed 's/"//g')
		peerNameVar="${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_NAME"

		peerContainerValue=$(echo "\"$(echo ${orgContainer} | base64 --decode | jq -r ${2})\"")
 		peerContainerValueStripped=$(echo $peerContainerValue | sed 's/"//g')
		peerContainerVar="${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_CONTAINER"

		peerHostValue=$(echo "\"$(echo ${orgContainer} | base64 --decode | jq -r ${3})\"")
		peerHostValueStripped=$(echo $peerHostValue | sed 's/"//g')
		peerHostVar="${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_HOST"

		peerUsernameValue=$(echo "\"$(echo ${orgContainer} | base64 --decode | jq -r ${4})\"")
		peerUsernameValueStripped=$(echo $peerUsernameValue | sed 's/"//g')
		peerUsernameVar="${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_USERNAME"

		peerPasswordValue=$(echo "\"$(echo ${orgContainer} | base64 --decode | jq -r ${5})\"")
		peerPasswordValueStripped=$(echo $peerPasswordValue | sed 's/"//g')
		peerPasswordVar="${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_PASSWORD"

		peerPathValue=$(echo "\"$(echo ${orgContainer} | base64 --decode | jq -r ${6})\"")
		peerPathValueStripped=$(echo $peerPathValue | sed 's/"//g')
		peerPathVar="${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_PATH"

		source .env

		# add name
		addEnvVariable $peerNameValueStripped "${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_NAME" "${!peerNameVar}"
 
		# add container
		addEnvVariable $peerContainerValueStripped "${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_CONTAINER" "${!peerContainerVar}"

		# add host
		addEnvVariable $peerHostValueStripped "${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_HOST" "${!peerHostVar}"

		# add username
		addEnvVariable $peerUsernameValueStripped "${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_USERNAME" "${!peerUsernameVar}"

		# add password
		addEnvVariable $peerPasswordValueStripped "${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_PASSWORD" "${!peerPasswordVar}"

		# add path
		addEnvVariable $peerPathValueStripped "${orgLabelValueStripped^^}_ORG_${peerNameValueStripped^^}_PATH" "${!peerPathVar}"

		source .env
	}
	echo $(_jq '.name' '.container' '.host' '.username' '.password' '.path')
done

#source .env

echo "### Organization ${orgLabelValueStripped^^} environment data added successfully to Cerberusntw network"


