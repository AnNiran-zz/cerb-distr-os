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

pathConfigFiles=cerberus-config/org/

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
cerberusOrgRemoteContainers=$(jq -r '.runningRemotely[]' $cerberusOrgConfigFile)
resultRemoteContainers=$?

if [ $resultRemoteContainers -ne 0 ]; then
        echo "ERROR: File format for $cerberusOrgConfigFile does not match expected"
        exit 1
fi

cerberusOrgLocalContainers=$(jq -r '.runningOnHost[]' $cerberusOrgConfigFile)
resultLocalContainers=$?

if [ $resultLocalContainers -ne 0 ]; then
	echo "ERROR: File format for $cerberusOrgConfigFile does not match expected"
	exit 1
fi

# get length of array
length=$(jq '.runningOnHost | length' $cerberusOrgConfigFile)
echo $length

# case 1 - 0 containers 
# case 2 - 1 containers
# case 3 - more than 1 containers
if [ $length -eq 0 ]; then
	
	echo "No CerberusOrg containers running on local host"

elif [ $length -eq 1 ]; then

	echo "One CerberusOrg container running on local host"

else

	for localContainer in $(echo "${cerberusOrgLocalContainers}" | jq -r '. | @base64'); do
		_jq(){
			localContainerNameValue=$(echo "\"$(echo ${localContainer} | base64 --decode | jq -r ${1})\"")
			localContainerNameValueStripped=$(echo $localContainerNameValue | sed 's/"//g')

			localContainerHostValue=$(echo "\"$(echo ${localContainer} | base64 --decode | jq -r ${3})\"")
			localContainerHostValueStripped=$(echo $localContainerHostValue | sed 's/"//g')

			for remoteContainer in $(echo "${cerberusOrgRemoteContainers}" | jq -r '. | @base64'); do
				_jq(){
					remoteContainerNameValue=$(echo "\"$(echo ${remoteContainer} | base64 --decode | jq -r ${1})\"")
					remoteContainerNameValueStripped=$(echo $remoteContainerNameValue | sed 's/"//g')

					remoteContainerHostValue=$(echo "\"$(echo ${remoteContainer} | base64 --decode | jq -r ${2})\"")
					remoteContainerHostValueStripped=$(echo $remoteContainerHostValue | sed 's/"//g')
					remoteContainerHostVar="CERBERUSORG_${remoteContainerNameValueStripped^^}_HOST"

					# check if variable is set in the environment
					if [ -z "${!remoteContainerHostVar}" ]; then
						echo "Required CerberusOrg environment data is missing. Obtaining ... "
						bash scripts/cerberus/addCerberusOrgExternalPeersToEnv.sh
					fi

					# check if the currently set variable in the environment has the same value as the one in the configuration file
					if [ "${!remoteContainerHostVar}" != "${remoteContainerHostValueStripped}" ]; then
						echo "Currently set host address for $remoteContainerNameValueStripped in environment does not match configuration data records."
						echo "Updating ... "
						bash scripts/cerberus/addCerberusOrgExternalPeersToEnv.sh
					fi

					
			
				}
				echo $(_jq '.name' '.host')
			done

			hosts=$(yq r --tojson $pathConfigFiles$localContainerNameValueStripped.yaml services["${localContainerNameValueStripped}".cerberusorg.cerberus.net].extra_hosts)
			
			echo
			echo "Adding CerberusOrg remote hosts to ${localContainerNameValueStripped} ..."

			if [ "$hosts" == null ]; then

				# if container is running - stop it
				if [ "$(docker inspect -f '{{.State.Running}}' $localContainerNameValueStripped.cerberusorg.cerberus.net)" == "true" ]; then
			
					echo
					echo " Stopping container $localContainerNameValueStripped.cerberusorg.cerberus.net ... "
					docker stop "${localContainerNameValueStripped}.cerberusorg.cerberus.net"
					sleep 10
				fi

				yq write --inplace $pathConfigFiles$localContainerNameValueStripped.yaml services["${localContainerNameValueStripped}".cerberusorg.cerberus.net].extra_hosts[+] null

				for remoteContainer in $(echo "${cerberusOrgRemoteContainers}" | jq -r '. | @base64'); do
					_jq(){
	                                        remoteContainerContainerValue=$(echo "\"$(echo ${remoteContainer} | base64 --decode | jq -r ${1})\"")
        	                                remoteContainerContainerValueStripped=$(echo $remoteContainerContainerValue | sed 's/"//g')

                                        	remoteContainerHostValue=$(echo "\"$(echo ${remoteContainer} | base64 --decode | jq -r ${2})\"")
                                        	remoteContainerHostValueStripped=$(echo $remoteContainerHostValue | sed 's/"//g')
                                        	remoteContainerHostVar="CERBERUSORG_${remoteContainerNameValueStripped^^}_HOST"

						extraHost="\"$remoteContainerContainerValueStripped:$remoteContainerHostValueStripped\""

						yq write --inplace $pathConfigFiles$localContainerNameValueStripped.yaml services["${localContainerNameValueStripped}".cerberusorg.cerberus.net].extra_hosts[+] $extraHost
						resultWrite=$?

						echo $resultWrite

						echo "Added ${remoteContainerContainerValueStripped} in list of extra_hosts for ${localContainerNameValueStripped}.cerberusorg.cerberus.net"
					}
					echo $(_jq '.container' '.host')
				done

				yq delete --inplace $pathConfigFiles$localContainerNameValueStripped.yaml services["${localContainerNameValueStripped}".cerberusorg.cerberus.net].extra_hosts[0]

				# start container
				echo
				echo " Starting container $localContainerNameValueStripped.cerberusorg.cerberus.net ... "
                                docker start "${localContainerNameValueStripped}.cerberusorg.cerberus.net"
                                sleep 10

			else


			fi

	
		}
		echo $(_jq '.name' '.container' '.host' '.username' '.password' '.path')
	done
fi
