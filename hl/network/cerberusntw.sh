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

# default image tag
IMAGETAG="latest"


