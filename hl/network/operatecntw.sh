#!/bin/bash

# prepending $PWD/../bin to PATH to ensure we are picking up the correct binaries
# this may be commented out to resolve installed version of tools if desired
export PATH=${PWD}/../bin:${PWD}:$PATH
export FABRIC_CFG_PATH=${PWD}
export VERBOSE=false

. cerberusntw.sh 
. extorgcerbntw.sh

# Print the usage message
function printHelp() {
	echo
	echo "### Commands: ###"
	echo
	echo "operatecntw.sh <action>"
	echo "	generate"
	echo "		Generates required certificates and genesis block for channels PersonAccounts, InstitutionAccounts and IntegrationAccounts"
	echo
	echo "	network-up"
	echo "		Generates required certifictaes and genesis block for channels PersonAccounts, InstitutionAccount and IntegrationAccounts"
	echo "		Starts all containers for Ordering Service instances and CerberusOrg"
	echo
	echo "	network-down"
	echo "		Stops all running containers for Ordering Service instances and CerberusOrg"
	echo "		Deletes all created certificates and genesis block for channels PersonAccounts, InstitutionAccounts and IntegrationAccounts"
	echo
	echo
	echo "	deliver-network-data"
	echo "		Checks if organization data is set in environment variables"
        echo "		Delivers Cerberus network hosts data to external organization host machines"
	echo "		To deliver network data to a single organization:"
	echo "		-o <organization-name>"
	echo "		To deliver network data to all organizations inside external-orgs/ folder:"
	echo "		-o all"
	echo
	echo 
	echo "	add-org-env"
	echo "		Adds organization host machines data to environemnt configuration file"
	echo "		To add environment data for a single organization:"
	echo "		-o <organization-name>"
	echo "		To add environment data for all organizaitons in external-orgs/ folder:"
	echo "		-o all"
	echo
	echo
	echo "	remove-org-env"
	echo "		Removes organization host machines data from environment configuration file"
	echo "		To add environment data for a single organization:"
        echo "		-o <organization-name>"
        echo "		To add environment data for all organizaitons in external-orgs/ folder:"
        echo "		-o all"
	echo
	echo
	echo "	add-org-extra-hosts -o <organization-name>"
	echo "		Adds organization extra hosts to Cerberus network organization and Ordering Service instances configuration files"
	echo
	echo
	echo "	remove-org-extra-hosts -o <organization-name>"
        echo "		Removes organization extra hosts from Cerberus network organization and Ordering Service instances configuration files"
        echo
	echo
	echo "	add-env-r"
	echo "		Adds Cerberus organization, Ordering Service instances and organizations environment data to organization remotely"
	echo "		To add the data to a single organization:"
	echo "		-o <destination-organization-name>"
	echo "		To add the data to all organizations:"
	echo "		-o all"
	echo "		To add environment data for Cerberus network and Ordering Service instances:"
	echo "		-e cerb"
	echo "		To add environment data remotely for all external organizations:"
	echo "		-e ext"
	echo "		To add environment data remotely for a specific external organization:"
	echo "		-e <organization-name>"
	echo "		To add environment data remotely for all entities:"
	echo "		-e all"
	echo "		Example:"
	echo "		./operatecntw.sh add-env-r -o myOrganization -e ext"
	echo
        echo "	remove-env-r"
        echo "		Removes Cerberus organization, Ordering Service instances and organizations environment data from organization remotely"
        echo "		To remove the data from a single organization:"
        echo "		-o <destination-organization-name>"
        echo "		To remove the data from all organizations:"
        echo "		-o all"
        echo "		To remove environment data for Cerberus network and Ordering Service instances:"
        echo "		-e cerb"
        echo "		To remove environment data remotely for all external organizations:"
        echo "		-e ext"
        echo "		To remove environment data remotely for a specific external organization:"
        echo "		-e <organization-name>"
        echo "		To remove environment data remotely for all entities:"
        echo "		-e all"
        echo "		Example:"
        echo "		./operatecntw.sh remove-env-r -o myOrganization -e ext"
	echo
	echo "	update-env-r"
        echo "		Updates Cerberus organization, Ordering Service instances and organizations environment data for organization remotely"
        echo "		To update the data on a single organization:"
        echo "		-o <destination-organization-name>"
        echo "		To update the data on all organizations:"
        echo "		-o all"
        echo "		To update environment data for Cerberus network and Ordering Service instances:"
        echo "		-e cerb"
        echo "		To update environment data remotely for all external organizations:"
        echo "		-e ext"
        echo "		To update environment data remotely for a specific external organization:"
        echo "		-e <organization-name>"
        echo "		To update environment data remotely for all entities:"
        echo "		-e all"
        echo "		Example:"
        echo "		./operatecntw.sh update-env-r -o myOrganization -e ext"
	echo
	echo "	add-extra-hosts-r"
	echo "		Adds Cerberus network, Ordering Service instances and external organizations extra hosts to desitnation host machines"
	echo "		To add extra hosts on a single organization:"
	echo "		-o <organization-name>"
	echo "		To add extra hosts on all external organizations:"
	echo "		-o all"
	echo "		To add extra hosts for Cerberus network organization and Ordering Service instances:"
	echo "		-e cerb"
	echo "		To add extra hosts for all external organizations:"
	echo "		-e ext"
	echo "		To add extra hosts gor Cerberus network organization, Ordering Service instances and all external organizations:"
	echo "		-e network"
	echo "		To add extra hosts for specific organization:"
	echo "		-e <organization-name>"
	echo "		Example:"
	echo "		./operatecntw.sh add-extra-hosts-r -o myOrganization -e cerb"
	echo
        echo "	remove-extra-hosts-r"
        echo "		Removes Cerberus organization, Ordering Service instances and organizations extra hosts data from organization remotely"
        echo "		To remove the data from a single organization:"
        echo "		-o <destination-organization-name>"
        echo "		To remove the data from all organizations:"
        echo "		-o all"
        echo "		To remove extra hosts data for Cerberus network and Ordering Service instances:"
        echo "		-e cerb"
        echo "		To remove extra hosts data remotely for all external organizations:"
        echo "		-e ext"
        echo "		To remove extra hosts data remotely for a specific external organization:"
        echo "		-e <organization-name>"
        echo "		To remove extra hosts data remotely for all entities:"
        echo "		-e all"
        echo "		Example:"
        echo "          ./operatecntw.sh remove-extra-hosts-r -o myOrganization -e ext"
        echo
        echo "	update-extra-hosts-r"
        echo "		Updates Cerberus organization, Ordering Service instances and organizations extra hosts data for organization remotely"
        echo "		To update the data on a single organization:"
        echo "		-o <destination-organization-name>"
        echo "		To update the data on all organizations:"
        echo "		-o all"
        echo "		To update extra hosts data for Cerberus network and Ordering Service instances:"
        echo "		-e cerb"
        echo "		To update extra hosts data remotely for all external organizations:"
        echo "		-e ext"
        echo "		To update extra hosts data remotely for a specific external organization:"
        echo "		-e <organization-name>"
        echo "		To update extra hosts data remotely for all entities:"
        echo "		-e all"
        echo "		Example:"
        echo "		./operatecntw.sh update-extra-hosts-r -o myOrganization -e ext"
	echo
	echo "	create-org-channelctx"
	echo "		"
	echo "		"
	echo
	echo
	echo "	help"
	echo "		Displays this message"
	echo

	echo "  cerberusntw.sh <mode> [-c <channel name>] [-t <timeout>] [-d <delay>] [-f <docker-compose-file>] [-s <dbtype>] [-l <language>] [-o <consensus-type>] [-i <imagetag>] [-v]"
	echo "    <mode> - one of 'up', 'down', 'restart', 'generate' or 'upgrade'"
	echo "      - 'restart' - restart the network"
 	echo "    -t <timeout> - CLI timeout duration in seconds (defaults to 10)"
	echo "    -d <delay> - delay duration in seconds (defaults to 3)"
	echo "    -f <docker-compose-file> - specify which docker-compose file use (defaults to docker-compose-cli.yaml)"
	echo "    -v - verbose mode"
	echo
}

# Ask user for confirmation to proceed
function askProceed() {
         
	echo "Continue? [Y/n] "
	read -p " " ans
     
	case "$ans" in
	y | Y | "") 
		echo "proceeding ..."
		;;
	n | N)  
		echo "exiting..."
		exit 1
		;;
	*)      
		echo "invalid response"
		askProceed
		;;
	esac    
}

CHANNELS_LIST=''
CHANNEL_NAME=''
ORG=''
ENTITY=''

# Parse commandline args
if [ "$1" = "-m" ]; then # supports old usage, muscle memory is powerful!
	shift
fi
MODE=$1
shift

# Determine action

# ./operatecntw.sh help
if [ "$MODE" == "help" ]; then
	EXPMODE="Display help usage message"

# ./operatecntw network-up
elif [ "$MODE" == "network-up" ]; then
	EXPMODE="Starting Cerberus network"

# ./operatecntw.sh network-down
elif [ "$MODE" == "network-down" ]; then
	EXPMODE="Stopping Cerberus network"

# ./operatecntw.sh generate
elif [ "$MODE" == "generate" ]; then
	EXPMODE="Generating Cerberus certificates and genesis block for channels: PersonAccounts, InstitutionAccounts and IntegrationAccounts"

# ./operatecntw.sh deliver-network-data -o sipher
elif [ "$MODE" == "deliver-network-data" ]; then
	EXPMODE="Deliver Cerberus network data to organization host machines"

# ./operatecntw.sh add-org-env -o sipher
elif [ "$MODE" == "add-org-env" ]; then
	EXPMODE="Adding new organization environment data"

# ./operatecntw.sh remove-org-env -o sipher
elif [ "$MODE" == "remove-org-env" ]; then
	EXPMODE="Removing organization environment data"

# ./operatecntw.sh add-org-extra-hosts -o sipher
elif [ "$MODE" == "add-org-extra-hosts" ]; then
	EXPMODE="Adding external organization extra hosts to Cerberus configuration files"

# ./operatenctw.sh remove-org-extra-hosts -o sipher
elif [ "$MODE" == "remove-org-extra-hosts" ]; then
	EXPMODE="Removing external organization extra hosts from Cerberus configuration files"

###################################################################
# Remote operations
# Following starts scripts on remote host machines and perform actions on behalf of organizations hosts

# ./operatecntw.sh add-env-r
elif [ "$MODE" == "add-env-r" ]; then
	EXPMODE="Adding environment data to organization remotely"

# ./operatecntw.sh remove-env-r
elif [ "$MODE" == "remove-env-r" ]; then
	EXPMODE="Removing environment data from organization remotely"

# ./operatecntw.sh update-env-r
elif [ "$MODE" == "update-env-r" ]; then
	EXPMODE="Updating environment data on organization hosts remotely"

# ./operatecntw.sh add-extra-hosts-r
elif [ "$MODE" == "add-extra-hosts-r" ]; then
	EXPMODE="Adding extra hosts to destination hosts remotely"

# ./operatecntw.sh remove-extra-hosts-r
elif [ "$MODE" == "remove-extra-hosts-r" ]; then
	EXPMODE="Removing extra hosts from destination hosts remotely"

# ./operatecntw.sh update-extra-hosts-r
elif [ "$MODE" == "update-extra-hosts-r" ]; then
	EXPMODE="Updating extra hosts on destination hosts remotely"

##############################################################################

# ./operatecntw.sh create-org-channelctx
elif [ "$MODE" == "create-org-channelctx" ]; then
	EXPMODE="Creating organization channel configuration updates"

# ./operatecntw.sh deliver-certs
elif [ "${MODE}" == "deliver-certs" ]; then
	EXPMODE="Deliver Cerberus organization and Ordering Service instances certificates to organization hosts"






elif [ "$MODE" == "getorgartifacts" ]; then
	EXPMODE="Obtaining organization artifacts from remote hosts ..."

elif [ "$MODE" == "test" ]; then
	EXPMODE="testing"

elif [ "$MODE" == "connectorg" ]; then
	EXPMODE="Connecting to Cerberus network"

elif [ "$MODE" == "getartifacts" ]; then
	EXPMODE="Getting organization channel artifacts"

elif [ "$MODE" == "record" ]; then
	EXPMODE="Adding to records ..."

elif [ "$MODE" == "disconnectorg" ]; then
	EXPMODE="Disconnecting organization from network channels"

elif [ "$MODE" == "restart" ]; then
	EXPMODE="Restarting Cerberus network"

else
	printHelp
	exit 1
fi

while getopts "h?c:t:d:e:f:n:l:i:o:v" opt; do
	case "$opt" in
	h | \?)
		printHelp
		exit 0
		;;
	c)      
		CHANNEL_NAME=$OPTARG
		;;
	t)      
		CLI_TIMEOUT=$OPTARG
		;;
	d)      
		CLI_DELAY=$OPTARG
		;;
	e)
		ENTITY=$OPTARG
		;;
	f)      
		COMPOSE_FILE=$OPTARG
		;;
	n)      
		ORG=$OPTARG
		;;
	l)      
		CHANNELS_LIST=$OPTARG
		;;	
	i)      
		IMAGETAG=$(go env GOARCH)"-"$OPTARG
		;;
	o)      
		ORG=$OPTARG
		;;
	v)      
		VERBOSE=true
		;;
	esac    
done    
 
# Announce what was requested
echo "${EXPMODE}"

# ask for confirmation to proceed
askProceed

# ./operatecntw.sh help
if [ "${MODE}" == "help" ]; then
	printHelp

# ./operatecntw.sh network-up
elif [ "${MODE}" == "network-up" ]; then
	networkUp

# ./operatecntw.sh network-down
elif [ "${MODE}" == "network-down" ]; then
	networkDown

# ./operatecntw.sh generate
elif [ "${MODE}" == "generate" ]; then
	generateCerts
	replacePrivateKey
	generateChannelsArtifacts

# ./operatecntw.sh deliver-network-data -o sipher
elif [ "${MODE}" == "deliver-network-data" ]; then
	# check if organization option tag is provided
	if [ -z "$ORG" ]; then
		echo "Please provide organization name with '-o' option tag"
		printHelp
		exit 1
	fi

	if [ "${ORG}" == "all" ]; then
		# deliver network data to all organizations
		for file in external-orgs/*-data.json; do
			bash scripts/deliverNetworkData.sh $file
		done

	else
		# deliver network data to a single organization
		orgConfigFile="external-orgs/${ORG}-data.json"

		bash scripts/deliverNetworkData.sh $orgConfigFile
	fi

# ./operatecntw.sh addorgenv -o sipher
elif [ "${MODE}" == "add-org-env" ]; then

	# check if organization option tag is provided
	if [ -z "$ORG" ]; then
		echo "Please provide organization name with '-o' option tag"
		printHelp
		exit 1
	fi

	if [ "${ORG}" == "all" ]; then
		# add environment data for all organizarions
		for file in external-orgs/*-data.json; do
			bash scripts/addOrgEnvData.sh $file
		done
	else
		# add environment data for a single organization
		orgConfigFile="external-orgs/${ORG}-data.json"
		bash scripts/addOrgEnvData.sh $orgConfigFile
	fi


# ./operatecntw.sh remove-org-env -o sipher
elif [ "${MODE}" == "remove-org-env" ]; then

	# check if organization option tag is provided
	if [ -z "$ORG" ]; then
		echo "Please provide organization name with '-o' option tag"
		printHelp
		exit 1
	fi

	if [ "${ORG}" == "all" ]; then
                # add environment data for all organizarions
                for file in external-orgs/*-data.json; do
                        bash scripts/removeOrgEnvData.sh $file
                done
        else
                # add environment data for a single organization
                orgConfigFile="external-orgs/${ORG}-data.json"
                bash scripts/removeOrgEnvData.sh $orgConfigFile
        fi


# ./operatecntw.sh add-org-extra-hosts
elif [ "${MODE}" == "add-org-extra-hosts" ]; then

	# check if organization option tag is provided
	if [ -z "$ORG" ]; then
		echo "Please provide organization name with '-o' option tag"
		printHelp
		exit 1
	fi

	bash scripts/addOrgExtraHosts.sh $ORG

# ./operatecntw.sh remove-org-extra-hosts 
elif [ "${MODE}" == "remove-org-extra-hosts" ]; then

	        # check if organization option tag is provided
        if [ -z "$ORG" ]; then
                echo "Please provide organization name with '-o' option tag"
                printHelp
                exit 1
        fi

        bash scripts/removeOrgExtraHosts.sh $ORG

###################################################################
# Remote operations
# Following starts scripts on remote host machines and perform actions on behalf of organizations hosts

# add cerberus organization, ordering service instances and external organizations environment to remote organization hosts
# ./operatecntw.sh add-env-remotely
elif [ "${MODE}" == "add-env-r" ]; then

	# check if organization and entity option tags are provided
        if [ -z "$ORG" ]; then
                echo "Please provide organization name with '-o' option tag"
                printHelp
                exit 1
        fi

	if [ -z "$ENTITY" ]; then
                echo "Please provide entity setting with '-e' option tag"
                printHelp
                exit 1
        fi
	
	if [ "${ENTITY}" == "${ORG}" ]; then
		echo "ERROR: Destination and delivering organization names cannot be the same"
		printHelp
		exit 1
	fi

	if [ "${ORG}" == "all" ]; then
		# add environment data to all organizations
		for file in external-orgs/*data.json; do
			echo "here will be added for all orgs"
		done

	else
		if [ "${ENTITY}" == "cerb" ]; then
			# add cerberus data to destination hosts
			orgConfigFile=external-orgs/${ORG}-data.json
			bash scripts/addCerberusDataToOrgRemotely.sh $orgConfigFile "env"

		elif [ "${ENTITY}" == "ext" ]; then
			# add external organizations data to destination hosts
			destOrgConfigFile=external-orgs/${ORG}-data.json

			for file in external-orgs/*data.json; do
				if grep -q "$destOrgConfigFile" "$file" ; then
				#if [ "$file" == "$destOrgConfigFile" ]; then
					continue;
				fi

				bash scripts/addOrganizationDataToOrgRemotely.sh $destOrgConfigFile $file "env"
			done

		elif [ "${ENTITY}" == "network" ]; then
			# add cerberus data to destination hosts
                        destOrgConfigFile=external-orgs/${ORG}-data.json
                        bash scripts/addCerberusDataToOrgRemotely.sh $destOrgConfigFile "env"
			
			# add external organizations data to destination hosts
			for file in external-orgs/*data.json; do
                                if grep -q "$destOrgConfigFile" "$file" ; then
				#if [ "$file" == "$destOrgConfigFile" ]; then
                                        continue;
                                fi

                                bash scripts/addOrganizationDataToOrgRemotely.sh $destOrgConfigFile $file "env"
                        done

		else
			# add specific external organization data to destination hosts
			destOrgConfigFile=external-orgs/${ORG}-data.json
                        deliveryOrgConfigFile=external-orgs/${ENTITY}-data.json

                        bash scripts/addOrganizationDataToOrgRemotely.sh $destOrgConfigFile $deliveryOrgConfigFile "env"

		fi
	fi

# remove cerberus organization, ordering service instances and external organizations environment data from remote organization hosts
elif [ "${MODE}" == "remove-env-r" ]; then

	# check if organization and entity option tags are provided
        if [ -z "$ORG" ]; then
                echo "Please provide organization name with '-o' option tag"
                printHelp
                exit 1
        fi

        if [ -z "$ENTITY" ]; then
                echo "Please provide entity setting with '-e' option tag"
                printHelp
                exit 1
        fi

        if [ "${ENTITY}" == "${ORG}" ]; then
                echo "ERROR: Destination and delivering organization names cannot be the same"
                printHelp
                exit 1
        fi

	if [ "${ORG}" == "all" ]; then
                # remove environment data from all organizations
                for file in external-orgs/*data.json; do
                        echo "here will be removed for all orgs"
                done

        else
		if [ "${ENTITY}" == "cerb" ]; then
                        # remove cerberus data from destination hosts
                        orgConfigFile=external-orgs/${ORG}-data.json
                        bash scripts/removeCerberusEnvDataFromOrgRemotely.sh $orgConfigFile

		elif [ "${ENTITY}" == "ext" ]; then
			# remove external organizations data from destination hosts
			destOrgConfigFile=external-orgs/${ORG}-data.json

                        for file in external-orgs/*data.json; do
				if grep -q "$destOrgConfigFile" "$file" ; then
                                #if [ "$file" == "$destOrgConfigFile" ]; then
                                        continue;
                                fi

                                bash scripts/removeOrganizationEnvDataFromOrgRemotely.sh $destOrgConfigFile $file
                        done

		 elif [ "${ENTITY}" == "network" ]; then
                        # remove cerberus data from destination hosts
                        destOrgConfigFile=external-orgs/${ORG}-data.json
                        bash scripts/removeCerberusEnvDataFromOrgRemotely.sh $destOrgConfigFile

                        # remove external organizations data from destination hosts
                        for file in external-orgs/*data.json; do
				if grep -q "$destOrgConfigFile" "$file" ; then
                                #if [ "$file" == "$destOrgConfigFile" ]; then
                                        continue;
                                fi

                                bash scripts/removeOrganizationEnvDataFromOrgRemotely.sh $destOrgConfigFile $file
                        done

		else
			# remove specific external organization data from destination hosts
                        destOrgConfigFile=external-orgs/${ORG}-data.json
                        deliveryOrgConfigFile=external-orgs/${ENTITY}-data.json

                        bash scripts/removeOrganizationEnvDataFromOrgRemotely.sh $destOrgConfigFile $deliveryOrgConfigFile
		fi
	fi

# update cerberus organization, ordering service instances and external organizations environment data on remote hosts
elif [ "${MODE}" == "update-env-r" ]; then

        # check if organization and entity option tags are provided
        if [ -z "$ORG" ]; then
                echo "Please provide organization name with '-o' option tag"
                printHelp
                exit 1
        fi

        if [ -z "$ENTITY" ]; then
                echo "Please provide entity setting with '-e' option tag"
                printHelp
                exit 1
        fi

        if [ "${ENTITY}" == "${ORG}" ]; then
                echo "ERROR: Destination and delivering organization names cannot be the same"
                printHelp
                exit 1
        fi

	if [ "${ORG}" == "all" ]; then
                # update environment data to all organizations
                for file in external-orgs/*data.json; do
                        echo "here will be updated for all orgs"
                done

        else
                if [ "${ENTITY}" == "cerb" ]; then
                        # update cerberus data on destination hosts
                        orgConfigFile=external-orgs/${ORG}-data.json
                        bash scripts/removeCerberusEnvDataFromOrgRemotely.sh $orgConfigFile
			bash scripts/addCerberusDataToOrgRemotely.sh $orgConfigFile "env"

                elif [ "${ENTITY}" == "ext" ]; then
                        # update external organizations data on destination hosts
                        destOrgConfigFile=external-orgs/${ORG}-data.json

                        for file in external-orgs/*data.json; do
				if grep -q "$destOrgConfigFile" "$file" ; then
                                #if [ "$file" == "$destOrgConfigFile" ]; then
                                        continue;
                                fi

                                bash scripts/removeOrganizationEnvDataFromOrgRemotely.sh $destOrgConfigFile $file
				bash scripts/addOrganizationDataToOrgRemotely.sh $destOrgConfigFile $file "env"
                        done

                 elif [ "${ENTITY}" == "network" ]; then
                        # add cerberus data to destination hosts
                        destOrgConfigFile=external-orgs/${ORG}-data.json
                        bash scripts/removeCerberusEnvDataFromOrgRemotely.sh $destOrgConfigFile
			bash scripts/addCerberusDataToOrgRemotely.sh $destOrgConfigFile "env"

                        # add external organizations data to destination hosts
                        for file in external-orgs/*data.json; do
                                if [ "$file" == "$destOrgConfigFile" ]; then
                                        continue;
                                fi

                                bash scripts/removeOrganizationEnvDataFromOrgRemotely.sh $destOrgConfigFile $file
				bash scripts/addOrganizationDataToOrgRemotely.sh $destOrgConfigFile $file "env"
                        done

                else
                        # add specific external organization data to destination hosts
                        destOrgConfigFile=external-orgs/${ORG}-data.json
                        deliveryOrgConfigFile=external-orgs/${ENTITY}-data.json

                        bash scripts/removeOrganizationEnvDataFromOrgRemotely.sh $destOrgConfigFile $deliveryOrgConfigFile
			bash scripts/addOrganizationDataToOrgRemotely.sh $destOrgConfigFile $deliveryOrgConfigFile "env"
                fi
        fi

# add cerberus organization, ordering service instances and external organizations extra hosts to remote organization hosts
elif [ "${MODE}" == "add-extra-hosts-r" ]; then

	# check if organization and entity option tags are provided
        if [ -z "$ORG" ]; then
                echo "Please provide organization name with '-o' option tag"
                printHelp
                exit 1
        fi

        if [ -z "$ENTITY" ]; then
                echo "Please provide entity setting with '-e' option tag"
                printHelp
                exit 1
        fi

        if [ "${ENTITY}" == "${ORG}" ]; then
                echo "ERROR: Destination and delivering organization names cannot be the same"
                printHelp
                exit 1
        fi

	if [ "${ORG}" == "all" ]; then
                # update environment data to all organizations
                for file in external-orgs/*data.json; do
                        echo "here will be updated for all orgs"
                done

        else
		if [ "${ENTITY}" == "cerb" ]; then
			# add cerberus organization and ordering service instances extra hosts to organization remote hosts
			orgConfigFile=external-orgs/${ORG}-data.json

			bash scripts/addCerberusDataToOrgRemotely.sh $orgConfigFile "extrahosts"

		elif [ "${ENTITY}" == "ext" ]; then
			# add external organizations extra hosts to remote destination hosts
			destOrgConfigFile=external-orgs/${ORG}-data.json

			for file in external-orgs/*data.json; do
                                if grep -q "$destOrgConfigFile" "$file" ; then
				#if [ "$file" == "$destOrgConfigFile" ]; then
                                        continue;
                                fi

                                bash scripts/addOrganizationDataToOrgRemotely.sh $destOrgConfigFile $file "extrahosts"
                        done

		elif [ "${ENTITY}" == "network" ]; then
			# add cerberus organization and ordering service instances extra hosts to organization remote hosts
			orgConfigFile=external-orgs/${ORG}-data.json

                        bash scripts/addCerberusDataToOrgRemotely.sh $orgConfigFile "extrahosts"

			# add external organizations extra hosts to remote destination hosts
                        destOrgConfigFile=external-orgs/${ORG}-data.json

                        for file in external-orgs/*data.json; do
				if grep -q "$destOrgConfigFile" "$file" ; then
                                #if [ "$file" == "$destOrgConfigFile" ]; then
                                        continue;
                                fi

                                bash scripts/addOrganizationDataToOrgRemotely.sh $destOrgConfigFile $file "extrahosts"
                        done

		else
			# add specific external organizatyion extra hosts to destination host machines
			destOrgConfigFile=external-orgs/${ORG}-data.json
                        deliveryOrgConfigFile=external-orgs/${ENTITY}-data.json

			bash scripts/addOrganizationDataToOrgRemotely.sh $destOrgConfigFile $deliveryOrgConfigFile "extrahosts"
		fi
	fi

# remove cerberus organization and ordering service extra hosts from remote organization hosts
elif [ "${MODE}" == "remove-extra-hosts-r" ]; then

        # check if organization and entity option tags are provided
        if [ -z "$ORG" ]; then
                echo "Please provide organization name with '-o' option tag"
                printHelp
                exit 1
        fi

        if [ -z "$ENTITY" ]; then
                echo "Please provide entity setting with '-e' option tag"
                printHelp
                exit 1
        fi

        if [ "${ENTITY}" == "${ORG}" ]; then
                echo "ERROR: Destination and delivering organization names cannot be the same"
                printHelp
                exit 1
        fi

	# to be developed

elif [ "${MODE}" == "update-extra-hosts-r" ]; then

        # check if organization and entity option tags are provided
        if [ -z "$ORG" ]; then
                echo "Please provide organization name with '-o' option tag"
                printHelp
                exit 1
        fi

        if [ -z "$ENTITY" ]; then
                echo "Please provide entity setting with '-e' option tag"
                printHelp
                exit 1
        fi

        if [ "${ENTITY}" == "${ORG}" ]; then
                echo "ERROR: Destination and delivering organization names cannot be the same"
                printHelp
                exit 1
        fi

	# to be developed

##################################################################
# ./operatecntw.sh create-org-channelctx
elif [ "${MODE}" == "create-org-channelctx" ]; then
	
	# check if organization and entity option tags are provided
        if [ -z "$ORG" ]; then
                echo "Please provide organization name with '-o' option tag"
                printHelp
                exit 1
        fi

	        # check if channel option tag is provided
        if [ -z "$CHANNELS_LIST" ]; then
                echo "Please provide a list of channels names with '-l' option tag"
                echo "If you want to connect to more than one channel, please provide channel names separated with a comma and without spaces"
                echo "Examples:"
                echo "./cerberusntw.sh connectorg -n <org-name> -l pers"
                echo "./cerberusntw.sh connectorg -n <org-name> -l pers,inst"
                echo "./cerberusntw.sh connectorg -n <org-name> -l pers,inst,int"
                exit 1
        fi

	# create channel updates by fetcinh and updating the current data
	createChannelCtx
	
# ./operatecntw.sh deliver-certs
elif [ "${MODE}" == "deliver-certs" ]; then

	        # check if organization and entity option tags are provided
        if [ -z "$ENTITY" ]; then
                echo "Please provide entity name with '-e' option tag"
                printHelp
                exit 1
        fi

	if [ "${ENTITY}" == "ext" ]; then
		# deliver certificates to all organizations
		for file in external-orgs/*-data.json; do
			bash scripts/deliverCerberusCertificatesToOrg.sh $file
		done

	else
		# deliver certificates to specific organization
		orgConfigFile=external-orgs/${ENTITY}-data.json

		bash scripts/deliverCerberusCertificatesToOrg.sh $orgConfigFile
	fi

# ./operatecntw.sh deliver-channel-artifacts
elif [ "${MODE}" == "deliver-channel-artifacts" ]; then

	echo "To be developed"

# tested until here

elif [ "${MODE}" == "getorgartifacts" ]; then

	# check if organization option tag is provided
	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-n' option tag"
		printHelp
		exit 1
	fi

	source .env

	orgNameVar="${NEW_ORG^^}_ORG_NAME"
	if [ -z "${!orgNameVar}" ]; then
		echo "$NEW_ORG environment data has not been obtained yet."
		echo "Run ./cerberusntw.sh addorgenv -n $NEW_ORG first."
		exit 1
	fi

	# add environment variables

elif [ "${MODE}" == "test" ]; then

	# check if channel option tag is provided
	if [ -z "$ORG" ]; then
	       echo "Please provide organization name with '-o' option tag"
	       exit 1
	fi

	bash scripts/addOrgEnvData.sh $ORG


elif [ "${MODE}" == "connectorg" ]; then

	# check if channel option tag is provided
	if [ -z "$CHANNELS_LIST" ]; then
		echo "Please provide a list of channels names with '-l' option tag"
		echo "If you want to connect to more than one channel, please provide channel names separated with a comma and without spaces"
		echo "Examples:"
		echo "./cerberusntw.sh connectorg -n <org-name> -l pers"
		echo "./cerberusntw.sh connectorg -n <org-name> -l pers,inst"
		echo "./cerberusntw.sh connectorg -n <org-name> -l pers,inst,int"
		exit 1
	fi

	# check if organization option tag is provided
	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-n' option tag"
		printHelp
		exit 1
	fi

	connectToChannels

elif [ "${MODE}" == "record" ]; then

	. scripts/addToRecords.sh

	addOrgToRecords $NEW_ORG

elif [ "${MODE}" == "restart" ]; then ## Restart the network
	networkDown
	networkUp

elif [ "$MODE" == "disconnectorg" ]; then
	disconnectOrg

 
else
	printHelp
	exit 1
fi


