#!/bin/bash

org=$1

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
        echo "ERROR: $ORG_CONFIG_FILE file not found. Cannot proceed with parsing new organization configuration"
        exit 1
fi

source .env
source ~/.profile

orgLabelValue=$(jq -r '.label' $ORG_CONFIG_FILE)
orgLabelValueStripped=$(echo $orgLabelValue | sed 's/"//g')

orgContainers=$(jq -r '.containers[]' $ORG_CONFIG_FILE)

cd cerberus-config/
osinstances=(osinstance0 osinstance1 osinstance2 osinstance3 osinstance4)

for instance in "${osinstances[@]}"; do

	hosts=$(yq r --tojson cerberus-os.yaml services["${instance}".cerberus.net].extra_hosts)
	extraHostsParsed=$(echo ${extraHosts} | jq '. | to_entries[]')

	if [ "$hosts" == null ]; then
 		echo "No extra hosts to remove from container ${instance}"

	else
		echo
        	echo "### Stopping container ${instance}.cerberus.net ... "

        	#docker stop "${instance}.cerberus.net"
        	#sleep 10

        	echo
        	echo "Removing extra hosts for ${orgLabelValue^^} to container ${instance}.cerberus.net ..."

		for orgContainer in $(echo "${orgContainers}" | jq -r  '. | @base64'); do
			_jq() {
                                orgContainerValue=$(echo "$(echo ${orgContainer} | base64 --decode | jq -r ${1})")
                                orgContainerValueStripped=$(echo $orgContainer | sed 's/"//g')

                                for extraHost in $(echo "${extraHostParsed}" | jq -r '. | @base64'); do
                                        _jq(){
                                                key=$(echo "$(echo ${extraHost} | base64 --decode | jq -r ${1})")
                                                value=$(echo "$(echo ${extraHost} | base64 --decode | jq -r ${2})")

                                                valueStripped=$(echo $value | sed 's/"//g')
                                                valueContainer=$(echo $valueStripped | sed 's/:.*//g')

                                                if [ "${orgContainerValueStripped}" == "${valueContainer}" ]; then
                                                        yq delete --inplace cerberus-os.yaml services["${instance}".cerberus.net].extra_hosts[${key}]
                                                fi
                                        }
                                        echo $(_jq, '.key' '.value')
                                done
			}
			echo $(_jq '.container' '.host')
		done

                remainingHostsData=$(yq r --tojson cerberus-os.yaml services["${instance}".cerberus.net].extra_hosts)
                remainingHosts=$(echo "${remainingHostsData}" | jq -r '.[]')

                if [ -z "$remainingHosts" ]; then
                        # delete key
                        yq delete --inplace cerberus-os.yaml services["${instance}".cerberus.net].extra_hosts
                fi

                echo
                echo "### Starting container ${instance}.cerberus.net ... "

                #docker start "${instance}.cerberus.net"
                #sleep 10
	fi
done

echo
echo "### ${orgLabelValueStripped^^} extra hosts have been successfully removed from Cerberus network ordering service nodes configuration "

cerberusorgContainers=(anchorpr leadpr communicatepr cli)
for cerberusOrgContainer in "${cerberusorgContainers[@]}"; do

	hosts=$(yq r -j cerberus-org.yaml services["${cerberusOrgContainer}".cerberusorg.cerberus.net].extra_hosts)
	extraHostsParsed=$(echo ${extraHosts} | jq '. | to_entries[]')

	if [ "$hosts" == "null" ]; then
		echo "No extra hosts to remove from container ${container}"
	else
		echo
                echo "### Stopping container ${cerberusOrgContainer}.cerberusorg.cerberus.net ..."

                #docker stop "${cerberusOrgContainer}.cerberusorg.cerberus.net"
                #sleep 10

                echo
                echo "Removing extra hosts for ${orgLabelValueStripped^^} to container ${cerberusOrgContainer}.cerberusorg.cerberus.net ..."

               for container in $(echo "${orgContainers}" | jq -r '. | @base64'); do
			_jq(){
				orgContainerValue=$(echo "$(echo ${orgContainer} | base64 --decode | jq -r ${1})")
                                orgContainerValueStripped=$(echo $orgContainer | sed 's/"//g')

                                for extraHost in $(echo "${extraHostParsed}" | jq -r '. | @base64'); do
                                        _jq(){
                                                key=$(echo "$(echo ${extraHost} | base64 --decode | jq -r ${1})")
                                                value=$(echo "$(echo ${extraHost} | base64 --decode | jq -r ${2})")

                                                valueStripped=$(echo $value | sed 's/"//g')
                                                valueContainer=$(echo $valueStripped | sed 's/:.*//g')

                                                if [ "${orgContainerValueStripped}" == "${valueContainer}" ]; then
                                                        yq delete --inplace cerberus-os.yaml services["${instance}".cerberus.net].extra_hosts[${key}]
                                                fi
                                        }
                                        echo $(_jq, '.key' '.value')
                                done
			}
			echo $(_jq '.container' '.host')
		done

                remainingHostsData=$(yq r --tojson cerberus-org.yaml services["${cerberusOrgContainer}".cerberusorg.cerberus.net].extra_hosts)
                remainingHosts=$(echo "${remainingHostsData}" | jq -r '.[]')

                if [ -z "$remainingHosts" ]; then
                        # delete key
                        yq delete --inplace cerberus-org.yaml services["${cerberusOrgContainer}".cerberusorg.cerberus.net].extra_hosts
                fi

                echo
                echo "### Starting container ${cerberusOrgContainer}.cerberusorg.cerberus.net ..."

                #docker start "${cerberusOrgContainer}.cerberusorg.cerberus.net"
                #sleep 10
	fi
done

cd $CURRENT_DIR

echo
echo "### ${orgLabelValueStripped^^} extra hosts have been successfully removed from Cerberus network organization "

