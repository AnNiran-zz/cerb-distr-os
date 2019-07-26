#!/bin/bash
function removeOrgEnvironmentData() {
	org=$1
	CURRENT_DIR=$PWD

	# obtain data from json file
	ORG_CONFIG_FILE="external-orgs/${org}-data.json"
	if [ ! -f "$ORG_CONFIG_FILE" ]; then
		echo
		echo "ERROR: external-orgs/$org-data.json file not found. Cannot proceed with parsing organization data"
		exit 1
	fi

	orgLabelVar="${org^^}_ORG_LABEL"
	orgNameVar="${org^^}_ORG_NAME"

	orgHostVar="${org^^}_ORG_IP"

	orgHostUsernameVar="${org^^}_ORG_USERNAME"
	orgHostPasswordVar="${org^^}_ORG_PASSWORD"

	orgHostPathVar="${org^^}_ORG_HOSTPATH"

	source .env

	# remove lavel
	removeEnvVariable "${org^^}_ORG_LABEL" "${!orgLabelVar}"

	# remove name
	removeEnvVariable "${org^^}_ORG_NAME" "${!orgNameVar}"

	# remove host
	removeEnvVariable "${org^^}_ORG_IP" "${!orgHostVar}"

	# remove username and password
	removeEnvVariable "${org^^}_ORG_USERNAME" "${!orgHostUsernameVar}"
	removeEnvVariable "${org^^}_ORG_PASSWORD" "${!orgHostPasswordVar}"

	# remove host path
	removeEnvVariable "${org^^}_ORG_HOSTPATH" "${!orgHostPathVar}"

	echo "Organization ${org^} environment data successfully removed from Cerberus network"
}

function removeOrgHostsFromOs() {
	org=$1
	CURRENT_DIR=$PWD

	ORG_CONFIG_FILE="external-orgs/$org-data.json"
	if [ ! -f "$ORG_CONFIG_FILE" ]; then
		echo 
		echo "ERROR: $ORG_CONFIG_FILE file not found. Cannot proceed with parsing network configuration"
		exit 1
	fi

	orgContainers=$(jq '.containers' $ORG_CONFIG_FILE)
	host=$(jq -r '.host' $ORG_CONFIG_FILE)
	orgNameVar="${org^^}_ORG_NAME"

	cd cerberus-config/

	osinstances=(osinstance0 osinstance1 osinstance2 osinstance3 osinstance4)
	for instance in "${osinstances[@]}"
	do
		hosts=$(yq r --tojson cerberus-os.yaml services["${instance}".cerberus.net].extra_hosts)

		echo
		echo "### Stopping container ${instance}.cerberus.net ... "

		#docker stop "${instance}.cerberus.net"
		#sleep 10

		echo
		echo "Removing extra hosts for ${!orgNameVar} to container ${instance}.cerberus.net ..."

		if [ "$hosts" == null ]; then
			echo "No extra hosts to remove from container ${instance}"

		else
			for row in $(echo "${orgContainers}" | jq -r  '.[] | @base64'); do
				_jq() {
					extraHost=$(echo "$(echo ${row} | base64 --decode | jq -r ${1}):${host}")

					removeExtraHost $hosts $instance $extraHost "os"
				}
				echo $(_jq '.container')
			done
		fi

		remainingHostsData=$(yq r --tojson cerberus-os.yaml services["${instance}".cerberus.net].extra_hosts)
		remainingHosts=$(echo "${remainingHostsData}" | jq -r '.[]')

		if [ -z $remainingHosts ]; then	
			# delete key
			yq delete --inplace cerberus-os.yaml services["${instance}".cerberus.net].extra_hosts
		fi

		echo
		echo "### Starting container ${instance}.cerberus.net ... "

		#docker start "${instance}.cerberus.net"
		#sleep 10
	done

	cd $CURRENT_DIR

	echo
	echo "### ${!orgNameVar} extra hosts have been successfully removed from Cerberus network ordering service nodes configuration "
}

function removeOrgHostsFromNetworkOrg() {

	org=$1
	CURRENT_DIR=$PWD

	ORG_CONFIG_FILE="external-orgs/$org-data.json"
	if [ ! -f "$ORG_CONFIG_FILE" ]; then
		echo
		echo "ERROR: $ORG_CONFIG_FILE file not found. Cannot proceed with parsing network configuration"
		exit 1
	fi

	orgContainers=$(jq '.containers' $ORG_CONFIG_FILE)
	host=$(jq -r '.host' $ORG_CONFIG_FILE)
	orgNameVar="${org^^}_ORG_NAME"

	cd cerberus-config/

	cerberusorgContainers=(anchorpr leadpr communicatepr cli)
	for cerberusOrgContainer in "${cerberusorgContainers[@]}"
	do
		hosts=$(yq r -j cerberus-org.yaml services["${cerberusOrgContainer}".cerberusorg.cerberus.net].extra_hosts)

		echo
		echo "### Stopping container ${cerberusOrgContainer}.cerberusorg.cerberus.net ..."

		#docker stop "${cerberusOrgContainer}.cerberusorg.cerberus.net"
		#sleep 10

		echo
		echo "Removing extra hosts for ${!orgNameVar} to container ${cerberusOrgContainer}.cerberusorg.cerberus.net ..."

		if [ "$hosts" == "null" ]; then
			echo "No extra hosts to remove from container ${container}"

		else
			for container in $(echo "${orgContainers}" | jq -r '.[] | @base64'); do
				_jq(){
					extraHostContainer=$(echo "$(echo ${container} | base64 --decode | jq -r ${1})")
					extraHost="${extraHostContainer}:${host}"

					removeExtraHost $hosts $cerberusOrgContainer $extraHostContainer "org"
				}
				echo $(_jq '.container')
			done
		fi

		remainingHostsData=$(yq r --tojson cerberus-org.yaml services["${cerberusOrgContainer}".cerberusorg.cerberus.net].extra_hosts)
		remainingHosts=$(echo "${remainingHostsData}" | jq -r '.[]')

		if [ -z $remainingHosts ]; then
			# delete key
			yq delete --inplace cerberus-org.yaml services["${cerberusOrgContainer}".cerberusorg.cerberus.net].extra_hosts
		fi

		echo
		echo "### Starting container ${cerberusOrgContainer}.cerberusorg.cerberus.net ..."

		#docker start "${cerberusOrgContainer}.cerberusorg.cerberus.net"
		#sleep 10

	done

	cd $CURRENT_DIR

	echo
	echo "### ${!orgNameVar} extra hosts have been successfully removed from Cerberus network organization "
}

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

function removeExtraHost() {
	extraHosts=$1
	container=$2
	hostToRemove=$3
	entity=$4

	extraHostsParsed=$(echo ${extraHosts} | jq '. | to_entries[]')

	if [[ " ${extraHostsParsed[*]} " == *"$hostToRemove"* ]]; then
		for row in $(echo "${extraHostsParsed}" | jq -r '. | @base64'); do
			_jq() {
				key=$(echo "$(echo ${row} | base64 --decode | jq -r ${1})")
				value=$(echo "$(echo ${row} | base64 --decode | jq -r ${2})")
				
				if [[ "$value" == *"$hostToRemove"* ]]; then
					if [ $entity == "os" ]; then
						yq delete --inplace cerberus-os.yaml services["${container}".cerberus.net].extra_hosts[${key}]
					elif [ $entity == "org" ]; then
						yq delete --inplace cerberus-org.yaml services["${container}".cerberusorg.cerberus.net].extra_hosts[${key}]
					else
						echo "unknown type"
					fi
				fi
				echo "$hostToRemove removed from extra_hosts list in ${container}"
			}
			echo $(_jq '.key' '.value')
		done
	else
		echo "${hostToRemove} is not in the list of extra hosts for ${container}"
	fi
}

