#!/bin/bash

function addOrgToRecords() {
	orgName=$1
	
	# add new organization to json channel records
	CURRENT_DIR=$PWD

	ORG_CONFIG_FILE="external-orgs/${orgName}-data.json"
	if [ ! -f "$ORG_CONFIG_FILE" ]; then
		echo
		echo "ERROR: external-orgs/$orgName-data.json not found. Cannot proceed with parsing organization data."
		echo "Add configuration file inside external-orgs/ directory and run ./cerberusntw.sh record -n sipher in order to finish the configuration"
		exit 1
	fi

	name=$(jq -r '.name' "external-orgs/$orgName-data.json")
	host=$(jq -r '.host' "external-orgs/$orgName-data.json")
	username=$(jq -r '.username' "external-orgs/$orgName-data.json")
	password=$(jq -r '.password' "external-orgs/$orgName-data.json")

	containersData=$(jq -r '.containers | @base64' "external-orgs/$orgName-data.json")
	containers=$(echo "$(echo ${containersData} | base64 --decode)")
	
	cd network-config/
	touch org-data-updated.json

	jq '.organizations[.organizations| length] |= . + {"org":{"name":"'$name'","host":"'$host'","username":"'$username'","password":"'$password'","channels":[],"containers":'$containers'}}' org-data.json >org-data-updated.json

	rm org-data.json
	mv org-data-updated.json org-data.json
	
	echo "========= ${name} added to Cerberus Network organizations records ========="
}

function addChannelToOrgRecords() {
	echo "hello from this function"
}
