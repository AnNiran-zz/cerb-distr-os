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
cerberusOsConfigFile=cerberus-config/os/os-data.json

if [ ! -f "$cerberusOsConfigFile" ]; then
        echo
        echo "ERROR: $cerberusOsConfigFile file not found. Cannot proceed with parsing new orgation configuration"
        exit 1
fi

source .env
source ~/.profile

myHostValue=$(jq -r '.myHost' $cerberusOsConfigFile)
resultHost=$?

if [ $resultHost -ne 0 ]; then
        echo "ERROR: File format for $cerberusOsConfigFile does not match expected"
        exit 1
fi

myHostValueStripped=$(echo $myHostValue | sed 's/"//g')

# get os instances
osInstancesPeers=$(jq -r '.containers[].osInstances[]' $cerberusOsConfigFile)
resultOsInstances=$?

if [ $resultOsInstances -ne 0 ]; then
        echo "ERROR: File format for $cerberusOsConfigFile does not match expected"
        exit 1
fi

for osPeer in $(echo "${osInstancesPeers}" | jq -r '. | @base64'); do
	_jq(){
		osPeerNameValue=$(echo "\"$(echo ${osPeer} | base64 --decode | jq -r ${1})\"")
		osPeerNameValueStripped=$(echo $osPeerNameValue | sed 's/"//g')
		osPeerNameVar="${osPeerNameValueStripped^^}_NAME"
		
                osPeerHostValue=$(echo "\"$(echo ${osPeer} | base64 --decode | jq -r ${3})\"")
                osPeerHostValueStripped=$(echo $osPeerHostValue | sed 's/"//g')
                osPeerHostVar="${osPeerNameValueStripped^^}_HOST"

		if [ "${osPeerHostValueStripped}" != "${myHostValueStripped}" ]; then
			
                	osPeerContainerValue=$(echo "\"$(echo ${osPeer} | base64 --decode | jq -r ${2})\"")
                	osPeerContainerValueStripped=$(echo $osPeerContainerValue | sed 's/"//g')
                	osPeerContainerVar="${osPeerNameValueStripped^^}_CONTAINER"

                	osPeerUsernameValue=$(echo "\"$(echo ${osPeer} | base64 --decode | jq -r ${4})\"")
                	osPeerUsernameValueStripped=$(echo $osPeerUsernameValue | sed 's/"//g')
                	osPeerUsernameVar="${osPeerNameValueStripped^^}_USERNAME"
                
                	osPeerPasswordValue=$(echo "\"$(echo ${osPeer} | base64 --decode | jq -r ${5})\"")
                	osPeerPasswordValueStripped=$(echo $osPeerPasswordValue | sed 's/"//g')
                	osPeerPasswordVar="${osPeerNameValueStripped^^}_PASSWORD"

                	osPeerPathValue=$(echo "\"$(echo ${osPeer} | base64 --decode | jq -r ${6})\"")
                	osPeerPathValueStripped=$(echo $osPeerPathValue | sed 's/"//g')
                	osPeerPathVar="${osPeerNameValueStripped^^}_PATH"
		
			# add peer name
			addEnvVariable $osPeerNameValueStripped "${osPeerNameValueStripped^^}_NAME" "${!osPeerNameVar}"

			# add peer container
			addEnvVariable $osPeerContainerValueStripped "${osPeerNameValueStripped^^}_CONTAINER" "${!osPeerContainerVar}"

			# add peer host
			addEnvVariable $osPeerHostValueStripped "${osPeerNameValueStripped^^}_HOST" "${!osPeerHostVar}"

			# add peer username
			addEnvVariable $osPeerUsernameValueStripped "${osPeerNameValueStripped^^}_USERNAME" "${!osPeerUsernameVar}"

			# add peer password
			addEnvVariable $osPeerPasswordValueStripped "${osPeerNameValueStripped^^}_PASSWORD" "${!osPeerPasswordVar}"

			# add peer path
			addEnvVariable $osPeerPathValueStripped "${osPeerNameValueStripped^^}_PATH" "${!osPeerPathVar}"

		fi

		source .env
	}
	echo $(_jq '.name' '.container' '.host' '.username' '.password' '.path')
done

echo
echo "Cerberus Ordering Service instances successfully added to local environment"
echo


# get kafka instances
kafkaInstancesPeers=$(jq -r '.containers[].kafkaInstances[]' $cerberusOsConfigFile)
resultKafkaInstances=$?

if [ $resultKafkaInstances -ne 0 ]; then
        echo "ERROR: File format for $cerberusOsConfigFile does not match expected"
        exit 1
fi



