#!/bin/bash

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
