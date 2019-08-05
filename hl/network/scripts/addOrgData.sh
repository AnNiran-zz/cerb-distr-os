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

	ORG_CONFIG_FILE=$1

	orgLabelValue=$(jq -r '.label' $ORG_CONFIG_FILE)
	orgLabelValueStripped=$(echo $orgLabelValue | sed 's/"//g')

	source ~/.profile

	CURRENT_DIR=$PWD

	orgContainers=$(jq -r '.containers[]' $ORG_CONFIG_FILE)
	cd cerberus-config/

	osinstances=(osinstance0 osinstance1 osinstance2 osinstance3 osinstance4)

	for instance in "${osinstances[@]}"
	do
		hosts=$(yq r --tojson cerberus-os.yaml services["${instance}".cerberus.net].extra_hosts)

		echo
		echo "### Adding ${orgLabelValueStripped^} extra hosts to Ordering Service"

		if [ "$hosts" == null ]; then

			echo
			echo "### Stopping container ${instance}.cerberus.net ... "

			#docker stop "${instance}.cerberus.net"
			#sleep 10

			echo
			echo "Adding extra hosts for ${orgLabelValueStripped^} to container ${instance}.cerberus.net ..."

			yq write --inplace cerberus-os.yaml services["${instance}".cerberus.net].extra_hosts[+] null

			for orgContainer in $(echo "${orgContainers}" | jq -r  '. | @base64'); do
				_jq() {
					orgContainerValue=$(echo "\"$(echo ${orgContainer} | base64 --decode | jq -r ${1})\"")
					orgContainerValueStripped=$(echo $orgContainerValue | sed 's/"//g')

					hostValue=$(echo "\"$(echo ${orgContainer} | base64 --decode | jq -r ${2})\"")
					hostValueStripped=$(echo ${hostValue} | sed 's/"//g')

					extraHost="\"$orgContainerValueStripped:$hostValueStripped\""

					yq write --inplace cerberus-os.yaml services["${instance}".cerberus.net].extra_hosts[+] $extraHost
					echo "added ${orgContainerValueStripped}} in list of extra_hosts for $instance"
				}
				echo $(_jq '.container' '.host')
			done

			yq delete --inplace cerberus-os.yaml services["${instance}".cerberus.net].extra_hosts[0]

			echo
			echo "### Starting container ${instance}.cerberus.net ... "

			#docker start "${instance}.cerberus.net"
			#sleep 10

		else

			echo
			echo "### Stopping container ${instance}.cerberus.net ... "
	
			#docker stop "${instance}.cerberus.net"
			#sleep 10

			echo	
			echo "Adding extra hosts for ${orgLabelValueStripped^} to container ${instance}.cerberus.net ..."

			for orgContainer in $(echo "${orgContainers}" | jq -r  '. | @base64'); do
				_jq(){
					orgContainerValue=$(echo "\"$(echo ${orgContainer} | base64 --decode | jq -r ${1})\"")
					orgContainerValueStripped=$(echo $orgContainerValue | sed 's/"//g')

					hostValue=$(echo "\"$(echo ${orgContainer} | base64 --decode | jq -r ${2})\"")
					hostValueStripped=$(echo ${hostValue} | sed 's/"//g')

					extraHost="\"$orgContainerValueStripped:$hostValueStripped\""

					extraHostsParsed=$(echo ${hosts} | jq '. | to_entries[]')

					if [[ " ${extraHostsParsed[*]} " == *"$orgContainerValueStripped"* ]]; then
						echo "$extraHost already in list of extra hosts for $instance"
					else
						yq write --inplace cerberus-os.yaml services["${instance}".cerberus.net].extra_hosts[+] $extraHost
						echo "added ${orgContainerValueStripped}} in list of extra_hosts for $instance"
					fi
				}
				echo $(_jq '.container' '.host')
			done

			echo
			echo "### Starting container ${instance}.cerberus.net ... "

			#docker start "${instance}.cerberus.net"
			#sleep 10

			echo
			echo "### External hosts for ${orgLabelValueStripped^} has been successfully added to ${instance}.cerberus.net container"
		fi
	done

	cd $CURRENT_DIR

	echo
	echo "### External hosts for ${orgLabelValueStripped^} has been successfully added to Cerberus network ordering service nodes "
}

function addExtraHostsToNetworkOrg() {
	
	ORG_CONFIG_FILE=$1
 
	orgLabelValue=$(jq -r '.label' $ORG_CONFIG_FILE)
	orgLabelValueStripped=$(echo $orgLabelValue | sed 's/"//g')

	source ~/.profile

	CURRENT_DIR=$PWD

	orgContainers=$(jq -r '.containers[]' $ORG_CONFIG_FILE)
	cd cerberus-config/

	cerberusorgContainers=(anchorpr leadpr communicatepr cli)
	
	for cerberusOrgContainer in "${cerberusorgContainers[@]}"; do

		hosts=$(yq r -j cerberus-org.yaml services["${cerberusOrgContainer}".cerberusorg.cerberus.net].extra_hosts)

		echo
		echo "### Adding ${orgLabelValueStripped^} extra hosts to Cerberus Network organization"
		
		if [ "$hosts" == "null" ]; then
		
			echo
			echo "### Stopping container ${cerberusOrgContainer}.cerberusorg.cerberus.net ..."
		
			#docker stop "${cerberusOrgContainer}.cerberusorg.cerberus.net"
			#sleep 10

			echo
			echo "### Adding extra hosts for ${orgLabelValueStripped^} to container ${cerberusOrgContainer}.cerberusorg.cerberus.net ..."

			yq write --inplace cerberus-org.yaml services["${cerberusOrgContainer}".cerberusorg.cerberus.net].extra_hosts[+] null

			for orgContainer in $(echo "${orgContainers}" | jq -r  '. | @base64'); do
				_jq() {
					orgContainerValue=$(echo "\"$(echo ${orgContainer} | base64 --decode | jq -r ${1})\"")
					orgContainerValueStripped=$(echo $orgContainerValue | sed 's/"//g')

					hostValue=$(echo "\"$(echo ${orgContainer} | base64 --decode | jq -r ${2})\"")
					hostValueStripped=$(echo ${hostValue} | sed 's/"//g')

					extraHost="\"$orgContainerValueStripped:$hostValueStripped\""

					yq write --inplace cerberus-org.yaml services["${cerberusOrgContainer}".cerberusorg.cerberus.net].extra_hosts[+] $extraHost
					echo "added ${orgContainerValueStripped} in list of extra_hosts for $cerberusOrgContainer"
				}
				echo $(_jq '.container' '.host')
			done

			yq delete --inplace cerberus-org.yaml services["${cerberusOrgContainer}".cerberusorg.cerberus.net].extra_hosts[0]

			echo
			echo "### Starting container ${instance}.cerberus.net ... "

			#docker start "${instance}.cerberus.net"
			#sleep 10
		else

			echo
			echo "### Stopping container ${cerberusOrgContainer}.cerberusorg.cerberus.net ..."

			#docker stop "${cerberusOrgContainer}.cerberusorg.cerberus.net"
			#sleep 10

			echo
			echo "### Adding extra hosts for ${orgLabelValueStripped^} to container ${cerberusOrgContainer}.cerberusorg.cerberus.net ..."

			for orgContainer in $(echo "${orgContainers}" | jq -r  '. | @base64'); do
				_jq(){
					orgContainerValue=$(echo "\"$(echo ${orgContainer} | base64 --decode | jq -r ${1})\"")
					orgContainerValueStripped=$(echo $orgContainerValue | sed 's/"//g')

					hostValue=$(echo "\"$(echo ${orgContainer} | base64 --decode | jq -r ${2})\"")
					hostValueStripped=$(echo ${hostValue} | sed 's/"//g')

					extraHost="\"$orgContainerValueStripped:$hostValueStripped\""

					extraHostsParsed=$(echo ${hosts} | jq '. | to_entries[]')

					if [[ " ${extraHostsParsed[*]} " == *"$orgContainerValueStripped"* ]]; then
						echo "$extraHost already in list of extra hosts for $cerberusOrgContainer"
					else
						yq write --inplace cerberus-org.yaml services["${cerberusOrgContainer}".cerberusorg.cerberus.net].extra_hosts[+] $extraHost
						echo "added ${orgContainerValueStripped} in list of extra_hosts for $cerberusOrgContainer"
					fi
				}
				echo $(_jq '.container' '.host')
			done

			echo
			echo "### Starting container ${cerberusOrgContainer}.cerberusorg.cerberus.net ..."

			#docker start "${cerberusOrgContainer}.cerberusorg.cerberus.net"
			#sleep 10

			echo
			echo "### External hosts for ${orgLabelValueStripped^} has been successfully ${cerberusOrgContainer}.cerberusorg.cerberus.net"
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
	entity=$5
	echo $5
	echo "here"

	extraHostsParsed=$(echo ${extraHosts} | jq '. | to_entries[]')

	if [[ " ${extraHostsParsed[*]} " == *"$newHostContainer"* ]]; then
		echo "$newHost already in list of extra hosts for $container"
	else
		if [ "${entity}" == "os" ]; then
			yq write --inplace cerberus-os.yaml services["${container}".cerberus.net].extra_hosts[+] $newHost
			echo "added ${value} in list of extra_hosts for $container"
		elif [ "${entity}" == "org" ]; then
			yq write --inplace cerberus-org.yaml services["${container}".cerberusorg.cerberus.net].extra_hosts[+] $newHost
			echo "added ${value} in list of extra_hosts for $container"
		else
			echo "Unknown entity for Cerberus network"
			exit 1
		fi
	fi
}
