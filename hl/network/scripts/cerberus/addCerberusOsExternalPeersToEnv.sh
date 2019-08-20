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
osInstancesRemotePeers=$(jq -r '.runningRemotely[].osInstances[]' $cerberusOsConfigFile)
resultOsInstances=$?

if [ $resultOsInstances -ne 0 ]; then
        echo "ERROR: File format for $cerberusOsConfigFile does not match expected"
        exit 1
fi

for osPeer in $(echo "${osInstancesRemotePeers}" | jq -r '. | @base64'); do
	_jq(){
		osPeerNameValue=$(echo "\"$(echo ${osPeer} | base64 --decode | jq -r ${1})\"")
		osPeerNameValueStripped=$(echo $osPeerNameValue | sed 's/"//g')
		osPeerNameVar="${osPeerNameValueStripped^^}_NAME"
		
                osPeerContainerValue=$(echo "\"$(echo ${osPeer} | base64 --decode | jq -r ${2})\"")
                osPeerContainerValueStripped=$(echo $osPeerContainerValue | sed 's/"//g')
                osPeerContainerVar="${osPeerNameValueStripped^^}_CONTAINER"

		osPeerHostValue=$(echo "\"$(echo ${osPeer} | base64 --decode | jq -r ${3})\"")
                osPeerHostValueStripped=$(echo $osPeerHostValue | sed 's/"//g')
                osPeerHostVar="${osPeerNameValueStripped^^}_HOST"

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

		source .env
	}
	echo $(_jq '.name' '.container' '.host' '.username' '.password' '.path')
done

echo
echo "Cerberus Ordering Service instances successfully added to local environment"
echo


# get kafka instances
kafkaInstances=$(jq -r '.runningRemotely[].kafkaInstances[]' $cerberusOsConfigFile)
resultKafkaInstances=$?

if [ $resultKafkaInstances -ne 0 ]; then
        echo "ERROR: File format for $cerberusOsConfigFile does not match expected"
        exit 1
fi

for kafkaInstance in $(echo "${kafkaInstances}" | jq -r '. | @base64'); do
	_jq(){
		kafkaInstanceNameValue=$(echo "\"$(echo ${kafkaInstance} | base64 --decode | jq -r ${1})\"")
		kafkaInstanceNameValueStripped=$(echo $kafkaInstanceNameValue | sed 's/"//g')
		kafkaInstanceNameVar="${kafkaInstanceNameValueStripped^^}_NAME"

		kafkaInstanceContainerValue=$(echo "\"$(echo ${kafkaInstance} | base64 --decode | jq -r ${2})\"")
		kafkaInstanceContainerValueStripped=$(echo $kafkaInstanceContainerValue | sed 's/"//g')
		kafkaInstanceContainerVar="${kafkaInstanceNameValueStripped^^}_CONTAINER"

		kafkaInstanceHostValue=$(echo "\"$(echo ${kafkaInstance} | base64 --decode | jq -r ${3})\"")
		kafkaInstanceHostValueStripped=$(echo $kafkaInstanceHostValue | sed 's/"//g')
		kafkaInstanceHostVar="${kafkaInstanceNameValueStripped^^}_HOST"

		kafkaInstanceContainerValue=$(echo "\"$(echo ${kafkaInstance} | base64 --decode | jq -r ${2})\"")
		kafkaInstanceContainerValueStripped=$(echo $kafkaInstanceContainerValue | sed 's/"//g')
		kafkaInstanceContainerVar="${kafkaInstanceNameValueStripped^^}_CONTAINER"

		kafkaInstanceUsernameValue=$(echo "\"$(echo ${kafkaInstance} | base64 --decode | jq -r ${4})\"")
		kafkaInstanceUsernameValueStripped=$(echo $kafkaInstanceUsernameValue | sed 's/"//g')
		kafkaInstanceUsernameVar="${kafkaInstanceNameValueStripped^^}_USERNAME"

		kafkaInstancePasswordValue=$(echo "\"$(echo ${kafkaInstance} | base64 --decode | jq -r ${5})\"")
		kafkaInstancePasswordValueStripped=$(echo $kafkaInstancePasswordValue | sed 's/"//g')
		kafkaInstancePasswordVar="${kafkaInstanceNameValueStripped^^}_PASSWORD"

		kafkaInstancePathValue=$(echo "\"$(echo ${kafkaInstance} | base64 --decode | jq -r ${6})\"")
		kafkaInstancePathValueStripped=$(echo $kafkaInstancePathValue | sed 's/"//g')
		kafkaInstancePathVar="${kafkaInstanceNameValueStripped^^}_PATH"

		# add kafka instance name
		addEnvVariable $kafkaInstanceNameValueStripped "${kafkaInstanceNameValueStripped^^}_NAME" "${!kafkaInstanceNameVar}"
			
		# add kafka instance container
		addEnvVariable $kafkaInstanceContainerValueStripped "${kafkaInstanceNameValueStripped^^}_CONTAINER" "${!kafkaInstanceContainerVar}"

		# add kafka instance host
		addEnvVariable $kafkaInstanceHostValueStripped "${kafkaInstanceNameValueStripped^^}_HOST" "${!kafkaInstanceHostVar}"

		# add kafka instance username
		addEnvVariable $kafkaInstanceUsernameValueStripped "${kafkaInstanceNameValueStripped^^}_USERNAME" "${!kafkaInstanceUsernameVar}"

		# add kafka instance password
		addEnvVariable $kafkaInstancePasswordValueStripped "${kafkaInstanceNameValueStripped^^}_PASSWORD" "${!kafkaInstancePasswordVar}"

		# add kafka instance path
		addEnvVariable $kafkaInstancePathValueStripped "${kafkaInstanceNameValueStripped^^}_PATH" "${!kafkaInstancePathVar}"

		source .env
	}
	echo $(_jq '.name' '.container' '.host' '.username' '.password' '.path')
done

# get zookeepr instances
zkInstances=$(jq -r '.runningRemotely[].zkInstances[]' $cerberusOsConfigFile)
resultZkInstances=$?

if [ $resultZkInstances -ne 0 ]; then
	echo "ERROR: File format for $cerberusOsConfigFile does not match expected"
	exit 1
fi

for zkInstance in $(echo "${zkInstances}" | jq -r '. | @base64'); do
	_jq(){
		zkInstanceNameValue=$(echo "\"$(echo ${zkInstance} | base64 --decode | jq -r ${1})\"")
                zkInstanceNameValueStripped=$(echo $zkInstanceNameValue | sed 's/"//g')
                zkInstanceNameVar="${zkInstanceNameValueStripped^^}_NAME"

                zkInstanceHostValue=$(echo "\"$(echo ${zkInstance} | base64 --decode | jq -r ${3})\"")
                zkInstanceHostValueStripped=$(echo $zkInstanceHostValue | sed 's/"//g')
                zkInstanceHostVar="${zkInstanceNameValueStripped^^}_HOST"
		
		zkInstanceContainerValue=$(echo "\"$(echo ${zkInstance} | base64 --decode | jq -r ${2})\"")
		zkInstanceContainerValueStripped=$(echo $zkInstanceContainerValue | sed 's/"//g')
		zkInstanceContainerVar="${zkInstanceNameValueStripped^^}_CONTAINER"

		zkInstanceUsernameValue=$(echo "\"$(echo ${zkInstance} | base64 --decode | jq -r ${4})\"")
		zkInstanceUsernameValueStripped=$(echo $zkInstanceUsernameValue | sed 's/"//g')
		zkInstanceUsernameVar="${zkInstanceNameValueStripped^^}_USERNAME"

		zkInstancePasswordValue=$(echo "\"$(echo ${zkInstance} | base64 --decode | jq -r ${5})\"")
		zkInstancePasswordValueStripped=$(echo $zkInstancePasswordValue | sed 's/"//g')
		zkInstancePasswordVar="${zkInstanceNameValueStripped^^}_PASSWORD"

		zkInstancePathValue=$(echo "\"$(echo ${zkInstance} | base64 --decode | jq -r ${6})\"")
		zkInstancePathValueStripped=$(echo $zkInstancePathValue | sed 's/"//g')
		zkInstancePathVar="${zkInstanceNameValueStripped^^}_PATH"

		# add kafka instance name
		addEnvVariable $zkInstanceNameValueStripped "${zkInstanceNameValueStripped^^}_NAME" "${!zkInstanceNameVar}"
                        
		# add kafka instance container
		addEnvVariable $zkInstanceContainerValueStripped "${zkInstanceNameValueStripped^^}_CONTAINER" "${!zkInstanceContainerVar}"

		# add kafka instance host
		addEnvVariable $zkInstanceHostValueStripped "${zkInstanceNameValueStripped^^}_HOST" "${!zkInstanceHostVar}"

		# add kafka instance username
		addEnvVariable $zkInstanceUsernameValueStripped "${zkInstanceNameValueStripped^^}_USERNAME" "${!zkInstanceUsernameVar}"

		# add kafka instance password
		addEnvVariable $zkInstancePasswordValueStripped "${zkInstanceNameValueStripped^^}_PASSWORD" "${!zkInstancePasswordVar}"

		# add kafka instance path
		addEnvVariable $zkInstancePathValueStripped "${zkInstanceNameValueStripped^^}_PATH" "${!zkInstancePathVar}"

                source .env
	}
	echo $(_jq '.name' '.container' '.host' '.username' '.password' '.path')
done
