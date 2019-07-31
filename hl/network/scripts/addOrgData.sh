#!/bin/bash

function addOrgEnvData() { # add check for existing extra_hosts
	newOrg=$1

	ORG_CONFIG_FILE="external-orgs/${newOrg}-data.json"

	orgLabelValue=$(jq -r '.label' $ORG_CONFIG_FILE)
	orgLabelValueStripped=$(echo $orgLabelValue | sed 's/"//g')
	orgLabelVar="${orgLabelValueStripped^^}_ORG_LABEL"

	# add organization label
	addEnvVariable $orgLabelValueStripped "${orgLabelValueStripped^^}_ORG_LABEL" "${!orgLabelVar}"

	orgContainers=$(jq -r '.containers[]' $ORG_CONFIG_FILE)

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
	
	echo "### Organization ${newOrg^} environment data added successfully to Cerberusntw network"
}

function addExtraHostsToOs() {

	org=$1
	CURRENT_DIR=$PWD

	ORG_CONFIG_FILE="external-orgs/$org-data.json"
	if [ ! -f "$ORG_CONFIG_FILE" ]; then
		echo 
		echo "ERROR: $ORG_CONFIG_FILE file not found. Cannot proceed with parsing network configuration"
		exit 1
	fi 

	newOrgContainers=$(jq '.containers' $ORG_CONFIG_FILE)
	host=$(jq -r '.host' $ORG_CONFIG_FILE)
	orgNameVar="${org^^}_ORG_NAME"

	cd cerberus-config/

	osinstances=(osinstance0 osinstance1 osinstance2 osinstance3 osinstance4)
	for instance in "${osinstances[@]}"
	do
		hosts=$(yq r --tojson cerberus-os.yaml services["${instance}".cerberus.net].extra_hosts)


		if [ "$hosts" == null ]; then

			echo
			echo "### Stopping container ${instance}.cerberus.net ... "

			#docker stop "${instance}.cerberus.net"
			#sleep 10

			echo
			echo "Adding extra hosts for ${newOrg^} to container ${instance}.cerberus.net ..."

			yq write --inplace cerberus-os.yaml services["${instance}".cerberus.net].extra_hosts[+] null

			for row in $(echo "${newOrgContainers}" | jq -r  '.[] | @base64'); do
				_jq() {
					extraHost=$(echo "$(echo ${row} | base64 --decode | jq -r ${1}):${host}")

					yq write --inplace cerberus-os.yaml services["${instance}".cerberus.net].extra_hosts[+] $extraHost
				}
				echo $(_jq '.container')
			done

			yq delete --inplace cerberus-os.yaml services["${instance}".cerberus.net].extra_hosts[0]

			echo
			echo "### Starting container ${instance}.cerberus.net ... "

			#docker start "${instance}.cerberus.net"
			#sleep 10

		else

			# check if input and output files exist
			if [ ! -f new-extra-hosts.json ]; then
				touch new-extra-hosts.json
			fi

			if [ ! -f new-extra-hosts-json.json ]; then
				touch new-extra-hosts-json.json
			fi

			# make sure the input and out files are empty
			> new-extra-hosts.json
			> new-extra-hosts-json.json

			hostsParsed=$(echo ${hosts} | jq '. | to_entries[]')
			echo "{\"newHosts\": [" >> new-extra-hosts.json

			for container in $(echo "${newOrgContainers}" | jq -r  '.[] | @base64'); do
				_jq() {
					extraHost=$(echo "$(echo ${container} | base64 --decode | jq -r ${1})":${host})

					if [[ " ${hostsParsed[*]} " == *"$extraHost"* ]]; then
						echo "$extraHost already exists in extra_hosts list for $cerberusOrgContainer"
					else
						echo "$extraHost does not exist in extra_hosts list for $cerberusOrgContainer"
						echo "{\"host\": \"${extraHost}\"}," >> new-extra-hosts.json
					fi
				}
				echo $(_jq '.container')
			done

			# remove last comma and add closing brackets in the json array
			sed '$ s/,$//' new-extra-hosts.json > new-extra-hosts-json.json

			echo "]}" >> new-extra-hosts-json.json
			> new-extra-hosts.json

			newHosts=$(cat new-extra-hosts-json.json)
			> new-extra-hosts-json.json

			# check how many additional hosts have been gathered
			elements=$(echo $newHosts | jq '.newHosts | length')

			if [ $elements -ne 0 ]; then
				echo "Adding missing extra hosts to ${instance}.cerberus.net ... "

				echo
				echo "### Stopping container ${instance}.cerberus.net ... "

				#docker stop "${instance}.cerberus.net"
				#sleep 10
				
				echo
				echo "### Adding extra hosts for ${org^} to container ${instance}.cerberus.net ... "

				for newHostData in $(echo "${newHosts}" | jq -r '.newHosts[] | @base64'); do
					_jq(){
						newHost=$(echo "$(echo ${newHostData} | base64 --decode | jq -r ${1})")

						yq write --inplace cerberus-os.yaml services["${instance}".cerberus.net].extra_hosts[+] $newHost
					}
					echo $(_jq '.host')
				done

				echo
				echo "### Starting container ${instance}.cerberus.net ... "

				#docker start "${instance}.cerberus.net"
				#sleep 10

				echo
				echo "### External hosts for ${org^} has been successfully added to ${instance}.cerberus.net container"

			else
				echo
				echo "No extra hosts missing from ${instance}.cerberus.net"
				echo
			fi
		fi
	done

	cd $CURRENT_DIR

	echo
	echo "### External hosts for ${!orgNameVar} has been successfully added to Cerberus network ordering service nodes "
}

function addExtraHostsToNetworkOrg() {
	
	org=$1
	CURRENT_DIR=$PWD
 
	ORG_CONFIG_FILE="external-orgs/$org-data.json"
	if [ ! -f "$ORG_CONFIG_FILE" ]; then
		echo
		echo "ERROR: $ORG_CONFIG_GILE file not found. Cannot proceed with parsing network configuration."
		exit 1
	fi

	newOrgContainers=$(jq '.containers' $ORG_CONFIG_FILE)
	host=$(jq -r '.host' $ORG_CONFIG_FILE)
	orgNameVar="${org^^}_ORG_NAME"

	cd cerberus-config/

	cerberusorgContainers=(anchorpr leadpr communicatepr cli)
	for cerberusOrgContainer in "${cerberusorgContainers[@]}"; do

		hosts=$(yq r -j cerberus-org.yaml services["${cerberusOrgContainer}".cerberusorg.cerberus.net].extra_hosts)

		if [ "$hosts" == "null" ]; then
		
			echo
			echo "### Stopping container ${cerberusOrgContainer}.cerberusorg.cerberus.net ..."
		
			#docker stop "${cerberusOrgContainer}.cerberusorg.cerberus.net"
			#sleep 10

			echo
			echo "### Adding extra hosts for ${org^} to container ${cerberusOrgContainer}.cerberusorg.cerberus.net ..."

			yq write --inplace cerberus-org.yaml services["${cerberusOrgContainer}".cerberusorg.cerberus.net].extra_hosts[+] null

			for container in $(echo "${newOrgContainers}" | jq -r '.[] | @base64'); do
				_jq(){
					extraHost=$(echo "$(echo ${container} | base64 --decode | jq -r ${1}):${host}")

					yq write --inplace cerberus-org.yaml services["${cerberusOrgContainer}".cerberusorg.cerberus.net].extra_hosts[+] $extraHost
				}
				echo $(_jq '.container')
			done

			yq delete --inplace cerberus-org.yaml services["${cerberusOrgContainer}".cerberusorg.cerberus.net].extra_hosts[0]

			echo
			echo "### Starting container ${cerberusOrgContainer}.cerberusorg.cerberus.net ..."

			#docker start "${cerberusOrgContainer}.cerberusorg.cerberus.net"
			#sleep 10

		else
			
			# check if input and output files exist
			if [ ! -f new-extra-hosts.json ]; then
				touch new-extra-hosts.json
			fi

			if [ ! -f new-extra-hosts-json.json ]; then
				touch new-extra-hosts-json.json
			fi

			# make sure the input and output files are empty
			> new-extra-hosts.json
			> new-extra-hosts-json.json

			hostsParsed=$(echo ${hosts} | jq '. | to_entries[]')
			echo "{\"newHosts\": [" >> new-extra-hosts.json

			for container in $(echo "${newOrgContainers}" | jq -r '.[] | @base64'); do
				_jq(){
					extraHost=$(echo "$(echo ${container} | base64 --decode | jq -r ${1})":${host})

					if [[ " ${hostsParsed[*]} " == *"$extraHost"* ]]; then
						echo "$extraHost already exists in extra_hosts list for $cerberusOrgContainer"
					else	
						echo "$extraHost does not exist in extra_hosts list for $cerberusOrgContainer"
						echo "{\"host\": \"${extraHost}\"}," >> new-extra-hosts.json
					fi

				}
				echo $(_jq '.container')
			done

			# remove last comma and add closing brackets in the json array
			sed '$ s/,$//' new-extra-hosts.json > new-extra-hosts-json.json

			echo "]}" >> new-extra-hosts-json.json
			> new-extra-hosts.json

			newHosts=$(cat new-extra-hosts-json.json)
			> new-extra-hosts-json.json

			# check how many additional hosts have been gathered
			elements=$(echo $newHosts | jq '.newHosts | length')
			
			if [ $elements -ne 0 ]; then
				echo "Adding missing extra hosts to ${cerberusOrgContainer}.cerberusorg.cerberus.net ..."
		
				echo
				echo "### Stopping container ${cerberusOrgContainer}.cerberusorg.cerberus.net ..."

				#docker stop "${cerberusOrgContainer}.cerberusorg.cerberus.net"
				#sleep 10

				echo
				echo "### Adding extra hosts for ${org^} to container ${cerberusOrgContainer}.cerberusorg.cerberus.net ..."

				for newHostData in $(echo "${newHosts}" | jq -r '.newHosts[] | @base64'); do
					_jq(){
						newHost=$(echo "$(echo ${newHostData} | base64 --decode | jq -r ${1})")

						yq write --inplace cerberus-org.yaml services["${cerberusOrgContainer}".cerberusorg.cerberus.net].extra_hosts[+] $newHost

					}
					echo $(_jq '.host')	
				done

				echo
				echo "### Starting container ${cerberusOrgContainer}.cerberusorg.cerberus.net ..."

				#docker start "${cerberusOrgContainer}.cerberusorg.cerberus.net"
				#sleep 10

				echo
				echo "### External hosts for ${!orgNameVar} has been successfully ${cerberusOrgContainer}.cerberusorg.cerberus.net"

			else
				echo
				echo "No extra hosts missing from ${cerberusOrgContainer}.cerberusorg.cerberus.net"
				echo
			fi
		fi
	done

	cd $CURRENT_DIR
}

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

function addExtraHost() {
	extraHosts=$1 # existing extraHosts
	container=$2
	newHostContainer=$3
	newHost=$4
	type=$5

	extraHostsParsed=$(echo ${extraHosts} | jq '. | to_entries[]')

	if [[ " ${extraHostsParsed[*]} " == *"$newHostContainer"* ]]; then
		echo "$newHost already in list of extra hosts for $container"
	else
		if [ $type == "os" ]; then
			yq write --inplace cerberus-os.yaml services["${container}".cerberus.net].extra_hosts[+] $newHost
			echo "added ${newHost} in list of extra_hosts for $container"
		elif [ $type == "org" ]; then
			yq write --inplace cerberus-org.yaml services["${container}".cerberusorg.cerberus.net].extra_hosts[+] $newHost
			echo "added ${newHost} in list of extra_hosts for $container"
		else
			echo "unknown type"
		fi
	fi
}
