#!/bin/bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#

# This script will orchestrate a sample end-to-end execution of the Hyperledger
# Fabric network.
#
# The end-to-end verification provisions a sample Fabric network consisting of
# two organizations, each maintaining two peers, and a “solo” ordering service.
#
# This verification makes use of two fundamental tools, which are necessary to
# create a functioning transactional network with digital signature validation
# and access control:
#
# * cryptogen - generates the x509 certificates used to identify and
#   authenticate the various components in the network.
# * configtxgen - generates the requisite configuration artifacts for orderer
#   bootstrap and channel creation.
#
# Each tool consumes a configuration yaml file, within which we specify the topology
# of our network (cryptogen) and the location of our certificates for various
# configuration operations (configtxgen).  Once the tools have been successfully run,
# we are able to launch our network.  More detail on the tools and the structure of
# the network will be provided later in this document.  For now, let's get going...

# prepending $PWD/../bin to PATH to ensure we are picking up the correct binaries
# this may be commented out to resolve installed version of tools if desired
export PATH=${PWD}/../bin:${PWD}:$PATH
export FABRIC_CFG_PATH=${PWD}
export VERBOSE=false

. scripts/addOrgData.sh
. scripts/removeOrgData.sh

# Print the usage message
function printHelp() {
  echo "Usage: "
  echo "  cerberusntw.sh <mode> [-c <channel name>] [-t <timeout>] [-d <delay>] [-f <docker-compose-file>] [-s <dbtype>] [-l <language>] [-o <consensus-type>] [-i <imagetag>] [-v]"
  echo "    <mode> - one of 'up', 'down', 'restart', 'generate' or 'upgrade'"
  echo "      - 'up' - bring up the network with docker-compose up"
  echo "      - 'down' - clear the network with docker-compose down"
  echo "      - 'restart' - restart the network"
  echo "      - 'generate' - generate required certificates and genesis block"
  echo "    -t <timeout> - CLI timeout duration in seconds (defaults to 10)"
  echo "    -d <delay> - delay duration in seconds (defaults to 3)"
  echo "    -f <docker-compose-file> - specify which docker-compose file use (defaults to docker-compose-cli.yaml)"
  echo "    -i <imagetag> - the tag to be used to launch the network (defaults to \"latest\")"
  echo "    -v - verbose mode"
  echo "  cerberusntw.sh -h (print this message)"
  echo
  echo "Typically, one would first generate the required certificates and "
  echo "genesis block, then bring up the network. e.g.:"
  echo
  echo "	cerberusntw.sh generate -c mychannel"
  echo "	cerberusntw.sh up -c mychannel -s couchdb"
  echo "        cerberusntw.sh up -c mychannel -s couchdb -i 1.4.0"
  echo "	cerberusntw.sh up -l node"
  echo "	cerberusntw.sh down -c mychannel"
  echo "        cerberusntw.sh upgrade -c mychannel"
  echo
  echo "Taking all defaults:"
  echo "	cerberusntw.sh generate"
  echo "	cerberusntw.sh up"
  echo "	cerberusntw.sh down"
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

# Obtain CONTAINER_IDS and remove them
# TODO Might want to make this optional - could clear other containers
function clearContainers() {
	
	CONTAINER_IDS=$(docker ps -a | awk '($2 ~ /dev-*.*.personaccountscc.*/) {print $1}')

	if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" == " " ]; then
		echo "---- No containers available for deletion ----"
	else
		docker rm -f $CONTAINER_IDS
	fi

	CONTAINER_IDS=$(docker ps -a | awk '($2 ~ /dev-*.*.institutionaccountscc.*/) {print $1}')

	if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" == " " ]; then
		echo "---- No containers available for deletion ----"
	else
		docker rm -f $CONTAINER_IDS
	fi

	CONTAINER_IDS=$(docker ps -a | awk '($2 ~ /dev-*.*.integrationaccountscc.*/) {print $1}')

	if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" == " " ]; then
		echo "---- No containers available for deletion ----"
	else
		docker rm -f $CONTAINER_IDS
	fi
}

# Delete any images that were generated as a part of this setup
# specifically the following images are often left behind:
# TODO list generated image naming patterns
function removeUnwantedImages() {
	
	DOCKER_IMAGE_IDS=$(docker images | awk '($1 ~ /dev-*pr.*.persaccntschannelcc.*/) {print $3}')

	if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" == " " ]; then
		echo "---- No images available for deletion ----"
	else
		docker rmi -f $DOCKER_IMAGE_IDS
	fi

	DOCKER_IMAGE_IDS=$(docker images | awk '($1 ~ /dev-*pr.*.instaccntschannelcc.*/) {print $3}')

	if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" == " " ]; then
		echo "---- No images available for deletion ----"
	else
		docker rmi -f $DOCKER_IMAGE_IDS
	fi

	DOCKER_IMAGE_IDS=$(docker images | awk '($1 ~ /dev-*pr.*.integraccntschannelcc.*/) {print $3}')

	if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" == " " ]; then
		echo "---- No images available for deletion ----"
	else
		docker rmi -f $DOCKER_IMAGE_IDS
	fi
}

# Versions of fabric known not to work with this release of cerberus-network
BLACKLISTED_VERSIONS="^1\.0\. ^1\.1\.0-preview ^1\.1\.0-alpha"

# Do some basic sanity checking to make sure that the appropriate versions of fabric
# binaries/images are available.  In the future, additional checking for the presence
# of go or other items could be added.
function checkPrereqs() {
	
	source .env

	# Note, we check configtxlator externally because it does not require a config file, and peer in the
	# docker image because of FAB-8551 that makes configtxlator return 'development version' in docker
	LOCAL_VERSION=$(configtxlator version | sed -ne 's/ Version: //p')
	DOCKER_IMAGE_VERSION=$(docker run --rm hyperledger/fabric-tools:$IMAGETAG peer version | sed -ne 's/ Version: //p' | head -1)

	echo "LOCAL_VERSION=$LOCAL_VERSION"
	echo "DOCKER_IMAGE_VERSION=$DOCKER_IMAGE_VERSION"

	if [ "$LOCAL_VERSION" != "$DOCKER_IMAGE_VERSION" ]; then
		echo "=================== WARNING ==================="
		echo "  Local fabric binaries and docker images are  "
		echo "  out of  sync. This may cause problems.       "
		echo "==============================================="
	fi

	for UNSUPPORTED_VERSION in $BLACKLISTED_VERSIONS; do
		echo "$LOCAL_VERSION" | grep -q $UNSUPPORTED_VERSION
		if [ $? -eq 0 ]; then
			echo "ERROR! Local Fabric binary version of $LOCAL_VERSION does not match this newer version of BYFN and is unsupported. Either move to a later version of Fabric or checkout an earlier version of fabric-samples."
			exit 1
		fi

		echo "$DOCKER_IMAGE_VERSION" | grep -q $UNSUPPORTED_VERSION
		if [ $? -eq 0 ]; then
			echo "ERROR! Fabric Docker image version of $DOCKER_IMAGE_VERSION does not match this newer version of BYFN and is unsupported. Either move to a later version of Fabric or checkout an earlier version of fabric-samples."
			exit 1
		fi
	done
}

# Generate the needed certificates, the genesis block and start the network.
function networkUp() {
	
	checkPrereqs
	# generate artifacts if they don't exist
	if [ ! -d "crypto-config" ]; then
		generateCerts
		replacePrivateKey
		generateChannelsArtifacts
	fi

	IMAGE_TAG=$IMAGETAG docker-compose -f $COMPOSE_FILE_CERBERUSORG -f $COMPOSE_FILE_CERBERUSORG_CA -f $COMPOSE_FILE_OS up -d 2>&1

	if [ $? -ne 0 ]; then
		echo "ERROR !!!! Unable to start network"
		exit 1
	fi

	sleep 1
	echo "Sleeping 10s to allow kafka cluster to complete booting"
	sleep 9

	# now run the end to end script
	docker exec cli.cerberusorg.cerberus.net scripts/script.sh $PERSON_ACCOUNTS_CHANNEL $INSTITUTION_ACCOUNTS_CHANNEL $INTEGRATION_ACCOUNTS_CHANNEL $CLI_DELAY $LANGUAGE $CLI_TIMEOUT $VERBOSE
	if [ $? -ne 0 ]; then
		echo "ERROR !!!! Test failed"
		exit 1
	fi
}

# Tear down running network
function networkDown() {
	
	docker-compose -f $COMPOSE_FILE_OS -f $COMPOSE_FILE_CERBERUSORG -f $COMPOSE_FILE_CERBERUSORG_CA down --volumes --remove-orphans

	# Don't remove the generated artifacts -- note, the ledgers are always removed
	if [ "$MODE" != "restart" ]; then
		# Bring down the network, deleting the volumes
		#Delete any ledger backups
		docker run -v $PWD:/tmp/cerberus-network --rm hyperledger/fabric-tools:$IMAGETAG rm -Rf /tmp/cerberus-network/ledgers-backup

		#Cleanup the chaincode containers
		clearContainers

		#Cleanup images
		removeUnwantedImages

		# remove orderer block and other channel configuration transactions and certs
		rm -rf channel-artifacts/*.block channel-artifacts/*.tx crypto-config

		rm -f $COMPOSE_FILE_CERBERUSORG_CA
	fi
}

# Using docker-compose-ca-template.yaml, replace constants with private key file names
# generated by the cryptogen tool and output a docker-compose.yaml specific to this
# configuration
function replacePrivateKey() {
	
	# sed on MacOSX does not support -i flag with a null extension. We will use
	# 't' for our back-up's extension and delete it at the end of the function
	ARCH=$(uname -s | grep Darwin)
	if [ "$ARCH" == "Darwin" ]; then
		OPTS="-it"
 	else
		OPTS="-i"
	fi

	# Copy the template to the file that will be modified to add the private key
	cp $COMPOSE_FILE_CERBERUSORG_CA_TEMPLATE $COMPOSE_FILE_CERBERUSORG_CA

	# The next steps will replace the template's contents with the
	# actual values of the private key file names for the two CAs.
	CURRENT_DIR=$PWD
	cd crypto-config/peerOrganizations/cerberusorg.cerberus.net/ca/
	PRIV_KEY=$(ls *_sk)
	cd "$CURRENT_DIR"
	sed $OPTS "s/CA_PRIVATE_KEY/${PRIV_KEY}/g" $COMPOSE_FILE_CERBERUSORG_CA

 	if [ "$ARCH" == "Darwin" ]; then
		rm cerberusorg-config/cerberusorg-ca.yamlt
	fi
}

# We will use the cryptogen tool to generate the cryptographic material (x509 certs)
# for our various network entities.  The certificates are based on a standard PKI
# implementation where validation is achieved by reaching a common trust anchor.
#
# Cryptogen consumes a file - ``crypto-config.yaml`` - that contains the network
# topology and allows us to generate a library of certificates for both the
# Organizations and the components that belong to those Organizations.  Each
# Organization is provisioned a unique root certificate (``ca-cert``), that binds
# specific components (peers and orderers) to that Org.  Transactions and communications
# within Fabric are signed by an entity's private key (``keystore``), and then verified
# by means of a public key (``signcerts``).  You will notice a "count" variable within
# this file.  We use this to specify the number of peers per Organization; in our
# case it's two peers per Org.  The rest of this template is extremely
# self-explanatory.
#
# After we run the tool, the certs will be parked in a folder titled ``crypto-config``.

# Generates Org certs using cryptogen tool
function generateCerts() {

	which cryptogen
	if [ "$?" -ne 0 ]; then
		echo "cryptogen tool not found. exiting"
		exit 1
	fi

	echo
	echo "##########################################################"
	echo "##### Generate certificates using cryptogen tool #########"
	echo "##########################################################"

	if [ -d "crypto-config" ]; then
		rm -Rf crypto-config
	fi
	set -x
	cryptogen generate --config=./crypto-config.yaml
	res=$?
	set +x
	if [ $res -ne 0 ]; then
		echo "Failed to generate certificates..."
		exit 1
	fi
	echo
}

# The `configtxgen tool is used to create four artifacts: orderer **bootstrap
# block**, fabric **channel configuration transaction**, and two **anchor
# peer transactions** - one for each Peer Org.
#
# The orderer block is the genesis block for the ordering service, and the
# channel transaction file is broadcast to the orderer at channel creation
# time.  The anchor peer transactions, as the name might suggest, specify each
# Org's anchor peer on this channel.
#
# Configtxgen consumes a file - ``configtx.yaml`` - that contains the definitions
# for the sample network. There are three members - one Orderer Org (``OrdererOrg``)
# and two Peer Orgs (``Org1`` & ``Org2``) each managing and maintaining two peer nodes.
# This file also specifies a consortium - ``SampleConsortium`` - consisting of our
# two Peer Orgs.  Pay specific attention to the "Profiles" section at the top of
# this file.  You will notice that we have two unique headers. One for the orderer genesis
# block - ``TwoOrgsOrdererGenesis`` - and one for our channel - ``TwoOrgsChannel``.
# These headers are important, as we will pass them in as arguments when we create
# our artifacts.  This file also contains two additional specifications that are worth
# noting.  Firstly, we specify the anchor peers for each Peer Org
# (``peer0.org1.example.com`` & ``peer0.org2.example.com``).  Secondly, we point to
# the location of the MSP directory for each member, in turn allowing us to store the
# root certificates for each Org in the orderer genesis block.  This is a critical
# concept. Now any network entity communicating with the ordering service can have
# its digital signature verified.
#
# This function will generate the crypto material and our four configuration
# artifacts, and subsequently output these files into the ``channel-artifacts``
# folder.
#
# If you receive the following warning, it can be safely ignored:
#
# [bccsp] GetDefault -> WARN 001 Before using BCCSP, please call InitFactories(). Falling back to bootBCCSP.
#
# You can ignore the logs regarding intermediate certs, we are not using them in
# this crypto implementation.

# Generate orderer genesis block, channel configuration transaction and
# anchor peer update transactions
function generateChannelsArtifacts() {
	
	which configtxgen
	if [ "$?" -ne 0 ]; then
		echo "configtxgen tool not found. exiting"
		exit 1
	fi

	echo $CHANNEL_NAME

	echo "##########################################################"
	echo "#########  Generating Orderer Genesis block ##############"
	echo "##########################################################"

	# Note: For some unknown reason (at least for now) the block file can't be
	# named orderer.genesis.block or the orderer will fail to launch!
	set -x
	configtxgen -profile OSNModeKafka -channelID cerberusntw-sys-channel -outputBlock ./channel-artifacts/genesis.block
	set +x

	res=$?
	set +x
	if [ $res -ne 0 ]; then
		echo "Failed to generate orderer genesis block..."
		exit 1
	fi

	echo "###################################################################"
	echo "### Generating channel configuration transaction 'personacctsch.tx' ###"
	echo "###################################################################"
	set -x
	configtxgen -profile PersonAccountsChannel -outputCreateChannelTx ./channel-artifacts/${PERSON_ACCOUNTS_CHANNEL}.tx -channelID $PERSON_ACCOUNTS_CHANNEL
	res=$?
	set +x
	if [ $res -ne 0 ]; then
		echo "Failed to generate channel configuration transaction..."
		exit 1
	fi

	echo "###################################################################"
	echo "### Generating channel configuration transaction 'institutionacctsch.tx' ###"
	echo "###################################################################"
	set -x
	configtxgen -profile InstitutionAccountsChannel -outputCreateChannelTx ./channel-artifacts/${INSTITUTION_ACCOUNTS_CHANNEL}.tx -channelID $INSTITUTION_ACCOUNTS_CHANNEL
	res=$?
	set +x
	if [ $res -ne 0 ]; then
		echo "Failed to generate channel configuration transaction..."
		exit 1
	fi

	echo "###################################################################"
	echo "### Generating channel configuration transaction 'integrationacctsch.tx' ###"
	echo "###################################################################"
	set -x
	configtxgen -profile IntegrationAccountsChannel -outputCreateChannelTx ./channel-artifacts/${INTEGRATION_ACCOUNTS_CHANNEL}.tx -channelID $INTEGRATION_ACCOUNTS_CHANNEL
	res=$?
	set +x
	if [ $res -ne 0 ]; then
		echo "Failed to generate channel configuration transaction..."
		exit 1
	fi

	echo "###################################################################"
	echo "#######    Generating anchor peer update for CerberusOrgMSP   ##########"
	echo "###################################################################"
	set -x
	configtxgen -profile PersonAccountsChannel -outputAnchorPeersUpdate ./channel-artifacts/CerberusOrgMSPPersAccChAnchors.tx -channelID $PERSON_ACCOUNTS_CHANNEL -asOrg CerberusOrgMSP
	res=$?
	set +x
	if [ $res -ne 0 ]; then
		echo "Failed to generate anchor peer update for CerberusOrgMSP..."
		exit 1
	fi

	set -x
	configtxgen -profile InstitutionAccountsChannel -outputAnchorPeersUpdate ./channel-artifacts/CerberusOrgMSPInstAccChAnchors.tx -channelID $INSTITUTION_ACCOUNTS_CHANNEL -asOrg CerberusOrgMSP
	res=$?
	set +x
	if [ $res -ne 0 ]; then
		echo "Failed to generate anchor peer update for CerberusOrgMSP..."
		exit 1
	fi

	set -x
	configtxgen -profile IntegrationAccountsChannel -outputAnchorPeersUpdate ./channel-artifacts/CerberusOrgMSPIntgrAccChAnchors.tx -channelID $INTEGRATION_ACCOUNTS_CHANNEL -asOrg CerberusOrgMSP
	res=$?
	set +x
	if [ $res -ne 0 ]; then
		echo "Failed to generate anchor peer update for CerberusOrgMSP..."
		exit 1
	fi
}

function deliverNetworkData() {

	orgDataFile="external-orgs/${NEW_ORG}-data.json"
	if [ ! -f "$orgDataFile" ]; then
		echo
		echo "ERROR: external-orgs/$NEW_ORG-data.json file not found. Cannot proceed with obtaining organization data."
		exit 1
	fi

	source .env

	 # add environment variables
	addEnvironmentData $NEW_ORG

	osDataFile="network-config/os-data.json"
	if [ ! -f "$osDataFile" ]; then
		echo
		echo "ERROR: network-config/os-data.json file not found. Cannot proceed with copying network data to organization host"
		exit 1
	fi

	cerberusOrgDataFile="network-config/cerberusorg-data.json"
	if [ ! -f "$cerberusOrgDataFile" ]; then
		echo
		echo "ERROR: network-config/cerberusorg-data.json file not found. Cannot proceed with copying network data to organization host"
		exit 1
	fi

	# copy files to organization host
	which sshpass
	if [ "$?" -ne 0 ]; then
		echo "sshpass tool not found"
		exit 1
	fi

	orgUsername="${NEW_ORG^^}_ORG_USERNAME"
	orgPassword="${NEW_ORG^^}_ORG_PASSWORD"
	orgHost="${NEW_ORG^^}_ORG_IP"
	orgPath="${NEW_ORG^^}_ORG_HOSTPATH"
	orgName="${NEW_ORG^^}_ORG_NAME"

	sshpass -p "${!orgPassword}" scp $osDataFile ${!orgUsername}@${!orgHost}:${!orgPath}/hl/network/network-config
	sshpass -p "${!orgPassword}" scp $cerberusOrgDataFile ${!orgUsername}@${!orgHost}:${!orgPath}/hl/network/network-config

	if [ "$?" -ne 0 ]; then
		echo "ERROR: Cannot copy data files to ${!orgName} remote host."
		exit 1
	fi

	echo "Cerberus Network data files copied to ${!orgName} remote host successfully."
}

function addNetworkEnvDataRemotely() {

	# check if organization environment variables are set
	orgUsernameVar="${NEW_ORG^^}_ORG_USERNAME"
	orgPasswordVar="${NEW_ORG^^}_ORG_PASSWORD"
	orgHostVar="${NEW_ORG^^}_ORG_IP"
	orgHostPathVar="${NEW_ORG^^}_ORG_HOSTPATH"

	source .env

	if [ -z "${!orgUsernameVar}" ] || [ -z "${!orgPasswordVar}" ] || [ -z "${!orgHostVar}" ] || [ -z "${!orgHostPathVar}" ]; then
		echo "Required organization environment data is not present. Obtaining ... "
	
		addEnvironmentData $NEW_ORG
	fi

	source .env

	# set network data remotely
	which sshpass
	if [ "$?" -ne 0 ]; then
		echo "sshpass tool not found"
		exit 1
	fi

	sshpass -p "${!orgPasswordVar}" ssh ${!orgUsernameVar}@${!orgHostVar} "cd ${!orgHostPathVar}/hl/network && ./sipher.sh add-network-env"
	if [ "$?" -ne 0 ]; then
		echo "Cerberus network environment data is not added to ${NEW_ORG^} host."
		exit 1
	fi

	echo "Cerberus network environment data successfully added to ${NEW_ORG^} host"

}

function removeNetworkEnvDataRemotely() {

	# check if organization environment variables are set
	orgUsernameVar="${NEW_ORG^^}_ORG_USERNAME"
	orgPasswordVar="${NEW_ORG^^}_ORG_PASSWORD"
	orgHostVar="${NEW_ORG^^}_ORG_IP"
	orgHostPathVar="${NEW_ORG^^}_ORG_HOSTPATH"

	source .env

	if [ -z "${!orgUsernameVar}" ] || [ -z "${!orgPasswordVar}" ] || [ -z "${!orgHostVar}" ] || [ -z "${!orgHostPathVar}" ]; then
		echo "Required organization environment data is not present. Obtaining ... "

		addEnvironmentData $NEW_ORG
	fi

	source .env

	# remove network data remotely
	which sshpass
	if [ "$?" -ne 0 ]; then
		echo "sshpass tool not found"
		exit 1
	fi

	sshpass -p "${!orgPasswordVar}" ssh ${!orgUsernameVar}@${!orgHostVar} "cd ${!orgHostPathVar}/hl/network && ./${NEW_ORG}.sh remove-network-env"
	if [ "$?" -ne 0 ]; then
		echo "Cerberus network environment data is not removed from ${NEW_ORG^} host"
		exit 1
	fi

	echo "Cerberus network environment data successfully removed from ${NEW_ORG^} hosts"
}


function addOrgHostsToCerberus() {

	source ~/.profile
	source .env

	orgHostVar="${NEW_ORG^^}_ORG_IP"

	if [ -z "${!orgHostVar}" ]; then
		echo "Required organization environment data is not present. Obtaining ... "
 
 		addEnvironmentData $NEW_ORG
	fi

	source .env

	addExtraHostsToOs $NEW_ORG
	addExtraHostsToNetworkOrg $NEW_ORG

	orgNameVar="${NEW_ORG^^}_ORG_NAME"
	echo "Organization ${!orgNameVar} extra hosts added successfully to Cerberusntw network configuration files"
}

function addNetworkHostsRemotely() {
	
	# check if organization environment variables are set
	orgUsernameVar="${NEW_ORG^^}_ORG_USERNAME"
	orgPasswordVar="${NEW_ORG^^}_ORG_PASSWORD"
	orgHostVar="${NEW_ORG^^}_ORG_IP"
	orgHostPathVar="${NEW_ORG^^}_ORG_HOSTPATH"

	source .env

	if [ -z "${!orgUsernameVar}" ] || [ -z "${!orgPasswordVar}" ] || [ -z "${!orgHostVar}" ] || [ -z "${!orgHostPathVar}" ]; then
		echo "Required organization environment data is not present. Obtaining ... "
 
		addEnvironmentData $NEW_ORG
	fi

	source .env

	# add network data remotely
	which sshpass
	if [ "$?" -ne 0 ]; then
		echo "sshpass tool not found"
		exit 1
	fi
	
	sshpass -p "${!orgPasswordVar}" ssh ${!orgUsernameVar}@${!orgHostVar} "cd ${!orgHostPathVar}/hl/network && ./${NEW_ORG}.sh add-network-hosts"
	if [ "$?" -ne 0 ]; then
		echo "ERROR: Unable to add network hosts to organization remotely"
		exit 1
	fi

	echo "Cerberus hosts successfully added to remote organization hosts"
}

function removeNetworkHostsRemotely() {

	# check if organization environment variables are set
	orgUsernameVar="${NEW_ORG^^}_ORG_USERNAME"
	orgPasswordVar="${NEW_ORG^^}_ORG_PASSWORD"
	orgHostVar="${NEW_ORG^^}_ORG_IP"
	orgHostPathVar="${NEW_ORG^^}_ORG_HOSTPATH"

	source .env

	if [ -z "${!orgUsernameVar}" ] || [ -z "${!orgPasswordVar}" ] || [ -z "${!orgHostVar}" ] || [ -z "${!orgHostPathVar}" ]; then
		echo "Required organization environment data is not present. Obtaining ... "

		addEnvironmentData $NEW_ORG
	fi

	source .env

	# remove network data remotely
	which sshpass
	if [ "$?" -ne 0 ]; then
		echo "sshpass tool not found"	
		exit 1
	fi

	sshpass -p "${!orgPasswordVar}" ssh ${!orgUsernameVar}@${!orgHostVar} "cd ${!orgHostPathVar}/hl/network && ./${NEW_ORG}.sh remove-network-hosts"
	if [ "$?" -ne 0 ]; then
		echo "ERROR: Unable to add network hosts to organization remotely"
		exit 1
	fi

	echo "Cerberus hosts successfully removed from remote organization hosts"

	# check if network env variables are set on remote machine
	getVal=$(sshpass -p "${!orgPasswordVar}" ssh ${!orgUsernameVar}@${!orgHostVar} "cd ${!orgHostPathVar}/hl/network/scripts && ./testEnvVar.sh CERBERUS_OS_IP")

	if [ "${getVal}" != "not set" ]; then
		orgNameVar="${NEW_ORG^^}_ORG_NAME"

		echo
		echo "========="
		echo "NOTE:"
		echo "Cerberus network environment variables are still set on ${!orgNameVar} host machine."
		echo "You can remove them remotely by calling \" ./cerberusntw.sh remove-netenv-remotely -n ${NEW_ORG}\""
	fi
}

function deliverOrgArtifacts() {
	
	which sshpass
	if [ "$?" -ne 0 ]; then
		echo "sshpass tool not found"
		exit 1
	fi

	orgUsername="${NEW_ORG^^}_ORG_USERNAME"
	artifactsLocation=/home/${!orgUsername}/server/go/src/cerberus


}

function parseChannelNames() {

	namesList=$1

	channels=$(echo $namesList | tr "," "\n")

	for channel in $channels; do
		if [ "$channel" != "person" ] && [ "$channel" != "institution" ] && [ "$channel" != "integration" ]; then
			echo "Channel name: $channel unknown"
			exit 1
		fi
	done

}

function connectToChannels() {

	channels=$(echo $CHANNELS_LIST | tr "," "\n")

	for channel in $channels; do
		if [ "$channel" == "pers" ]; then
			echo "Connecting ${NEW_ORG^} to Cerberus Network channel: Person Accounts"
			docker exec cli.cerberusorg.cerberus.net scripts/addOrgToPersonAccChannel.sh $NEW_ORG $PERSON_ACCOUNTS_CHANNEL
 			
			if [ $? -ne 0 ]; then
				echo "Unable to create config tx for ${PERSON_ACCOUNTS_CHANNEL}"
 				exit 1
			fi

		elif [ "$channel" == "inst" ]; then
 			echo "Connecting ${NEW_ORG^} to Cerberus Network channel: Institution Accounts"
 			docker exec cli.cerberusorg.cerberus.net scripts/addOrgToInstitutionAccChannel.sh $NEW_ORG $INSTITUTION_ACCOUNTS_CHANNEL
 	
			if [ $? -ne 0 ]; then
				echo "Unable to create config tx for ${INSTITUTION_ACCOUNTS_CHANNEL}"
				exit 1
			fi

		elif [ "$channel" == "int" ]; then
			echo "Connecting ${NEW_ORG^} to Cerberus Network channel: Integration Accounts"
			docker exec cli.cerberusorg.cerberus.net scripts/addOrgToIntegrationAccChannel.sh $NEW_ORG $INTEGRATION_ACCOUNTS_CHANNEL

			if [ $? -ne 0 ]; then
				echo "Unable to create config tx for ${INTEGRATION_ACCOUNTS_CHANNEL}"
				exit 1
			fi

		else 
			echo "Channel name: $channel unknown"
			exit 1
		fi
	done	
}


function disconnectOrg() {
	. scripts/disconnectOrg.sh

	removeExternalOrgArtifacts $NEW_ORG
}

function parseYaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

# Obtain the OS and Architecture string that will be used to select the correct
# native binaries for your platform, e.g., darwin-amd64 or linux-amd64
OS_ARCH=$(echo "$(uname -s | tr '[:upper:]' '[:lower:]' | sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')
# timeout duration - the duration the CLI should wait for a response from
# another container before giving up
CLI_TIMEOUT=10
# default for delay between commands
CLI_DELAY=20

PERSON_ACCOUNTS_CHANNEL="persaccntschannel"
INSTITUTION_ACCOUNTS_CHANNEL="instaccntschannel"
INTEGRATION_ACCOUNTS_CHANNEL="integraccntschannel"

# use this as the default docker-compose yaml definition
COMPOSE_FILE_CERBERUSORG=cerberus-config/cerberus-org.yaml
COMPOSE_FILE_CERBERUSORG_CA_TEMPLATE=base/cerberusorg-ca-template.yaml
COMPOSE_FILE_CERBERUSORG_CA=cerberus-config/cerberusorg-ca.yaml
COMPOSE_FILE_OS=cerberus-config/cerberus-os.yaml
#
# use golang as the default language for chaincode
LANGUAGE=golang
CHANNELS_LIST=''
CHANNEL_NAME=''
# default image tag
IMAGETAG="latest"
NEW_ORG=''

# Parse commandline args
if [ "$1" = "-m" ]; then # supports old usage, muscle memory is powerful!
  shift
fi
MODE=$1
shift
# Determine whether starting, stopping, restarting, generating or upgrading
if [ "$MODE" == "up" ]; then
	EXPMODE="Starting Cerberus network"
elif [ "$MODE" == "down" ]; then
	EXPMODE="Stopping Cerberus network"

elif [ "$MODE" == "generate" ]; then
	EXPMODE="Generating Cerberus certificates and genesis block"

# ./cerberusntw.sh deliver-network-data -n sipher
elif [ "$MODE" == "deliver-network-data" ]; then
	EXPMODE="Deliver Cerberus network data to organization ..."

# ./cerberusntw.sh addorgenv -n sipher
elif [ "$MODE" == "add-org-env" ]; then
	EXPMODE="Adding new organization environment data"

# ./cerberusntw.sh removeorgenv -n sipher
elif [ "$MODE" == "remove-org-env" ]; then
	EXPMODE="Removing organization environment data"

# ./cerberusntw.sh add-netenv-remotely -n sipher
elif [ "$MODE" == "add-netenv-remotely" ]; then
	echo "This command will successfully add network data to organization remotely if network configuration files are present on the remote host machine address set inside \"external-orgs/<organization-name>-data.json\" file. If you are not certain about this run \"./cerberusntw.sh deliver-network-data -n <organization-name>\" first."

	EXPMODE="Adding network environment data to organization host remotely"

# ./cerberusntw.sh remove-netenv-remotely -n sipher
elif [ "$MODE" == "remove-netenv-remotely" ]; then
	EXPMODE="Removing network environment data from organization host remotely"

# ./cerberusntw.sh add-org-hosts -n sipher
elif [ "$MODE" == "add-org-hosts" ]; then
	EXPMODE="Adding organization hosts to local host containers"

# ./cerberusntw.sh remove-org-hosts -n sipher
elif [ "$MODE" == "remove-org-hosts" ]; then
	EXPMODE="Removing organization hosts from local host containers"

# ./cerberusntw.sh add-network-hosts-remotely -n sipher
elif [ "$MODE" == "add-network-hosts-remotely" ]; then
	EXPMODE="Adding network hosts to organization configuration remotely "

# ./cerberusntw.sh remove-network-hosts-remotely
elif [ "$MODE" == "remove-network-hosts-remotely" ]; then
	EXPMODE="Removing network hosts from organization configuration remotely "










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

while getopts "h?c:t:d:f:n:l:i:v" opt; do
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
	f)
		COMPOSE_FILE=$OPTARG
		;;
	n)
		NEW_ORG=$OPTARG
		;;
	l)
		CHANNELS_LIST=$OPTARG
		;;
 	i)
		IMAGETAG=$(go env GOARCH)"-"$OPTARG
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

#Create the network using docker compose
if [ "${MODE}" == "up" ]; then
	networkUp
elif [ "${MODE}" == "down" ]; then ## Clear the network
	networkDown
elif [ "${MODE}" == "generate" ]; then ## Generate Artifacts
	generateCerts
	replacePrivateKey
	generateChannelsArtifacts

# ./cerberusntw.sh deliver-network-data -n sipher
elif [ "${MODE}" == "deliver-network-data" ]; then
	# check if organization option tag is provided
	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-n' option tag"
		printHelp
		exit 1
	fi

	deliverNetworkData $NEW_ORG

# ./cerberusntw.sh addorgenv -n sipher
elif [ "${MODE}" == "add-org-env" ]; then
	
	# check if organization option tag is provided
	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-n' option tag"
		printHelp
		exit 1
	fi

	source .env

	# add environment variables
	addEnvironmentData $NEW_ORG

# ./cerberusntw.sh removeorgenv -n sipher
elif [ "${MODE}" == "remove-org-env" ]; then

	# check if organization option tag is provided
	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-n' option tag"
		printHelp
		exit 1
	fi
	
	source .env

	# remove environment variables
	removeOrgEnvironmentData $NEW_ORG

# ./cerberusntw.sh add-netenv-remotely -n sipher
elif [ "${MODE}" == "add-netenv-remotely" ]; then
	
	# check if organization option tag is provided
	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-n' option tag"
		printHelp
		exit 1
	fi

	addNetworkEnvDataRemotely

# ./cerberusntw.sh remove-netenv-remotely -n sipher
elif [ "${MODE}" == "remove-netenv-remotely" ]; then

	# check if organization option tag is provided
	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-n' option tag"
		printHelp
		exit 1
	fi

	removeNetworkEnvDataRemotely

# ./cerberusntw.sh add-org-hosts -n sipher
elif [ "${MODE}" == "add-org-hosts" ]; then

	# check if organization option tag is provided
	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-n' option tag"
		printHelp
		exit 1
	fi

	addOrgHostsToCerberus

# ./cerberusntw.sh remove-org-hosts -n sipher
elif [ "${MODE}" == "remove-org-hosts" ]; then

	# check if organization option tag is provided
	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-n' option tag"
		printHelp
		exit 1
	fi

	source ~/.profile

	removeOrgHostsFromOs $NEW_ORG
	removeOrgHostsFromNetworkOrg $NEW_ORG

	orgNameVar="${NEW_ORG^^}_ORG_NAME"
	if [ ! -z "${!orgNameVar}" ]; then
		echo "$NEW_ORG environment data is still present. You can remove it by running ./cerberusntw.sh removeorgenv -n $NEW_ORG"
	fi

# ./cerberusntw.sh add-network-hosts-remotely -n sipher
elif [ "${MODE}" == "add-network-hosts-remotely" ]; then
	
       	# check if organization option tag is provided
	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-n' option tag"
 		printHelp
		exit 1
	fi

	addNetworkHostsRemotely

# ./cerberusntw.sh remove-network-hosts-remotely -n sipher
elif [ "${MODE}" == "remove-network-hosts-remotely" ]; then
       
	# check if organization option tag is provided
 	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-n' option tag"
		printHelp
		exit 1
	fi

	removeNetworkHostsRemotely













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
	if [ -z "$CHANNELS_LIST" ]; then
		echo "Please provide a channels list with '-l' option tag"
		exit 1
	fi

	parseChannelNames $CHANNELS_LIST


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
