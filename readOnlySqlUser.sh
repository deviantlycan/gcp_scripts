#!/usr/bin/env bash
##########################################################################
## Name: readOnlySqlUser.sh
## Description: Creates a read only user in a Cloud Sql instance
## Author: Scott McArthur
##########################################################################
source ../std/std-functions.sh

GCP_PROJECT_ID=
DB_NAME=
SCHEMA_NAME=
DB_USER_NAME="readonlyuser"
DB_USER_PASS=

function main(){
	processScriptArgs
	init
	printHeader

	validateInputs
	createDbUser

	cleanup
	printFooter
}

function createDbUser(){
	createuser
	setuserpermissions
	listusers
}

function validateInputs(){
	if [[ -z "${DB_NAME}" ]]; then
		log "DB_NAME cannot be blank"
		printHelp
		failAndQuit
	fi

	if [[ -z "${SCHEMA_NAME}" ]]; then
		log "SCHEMA_NAME cannot be blank"
		printHelp
		failAndQuit
	fi

  if [[ -z "${GCP_PROJECT_ID}" ]]; then
		log "GCP_PROJECT_ID cannot be blank"
		printHelp
		failAndQuit
	fi
  
  if [[ -z "${DB_USER_PASS}" ]]; then
		log "DB_USER_PASS cannot be blank"
		printHelp
		failAndQuit
	fi
}

function createuser(){
	log "Creating user ${DB_USER_NAME} for instance ${DB_NAME} in project ${GCP_PROJECT_ID}"
	gcloud sql users create ${DB_USER_NAME} --instance ${DB_NAME} --password ${DB_USER_PASS} --host=% --project=${GCP_PROJECT_ID}
}

function deleteuser(){
	log "Deleting user ${DB_USER_NAME} for instance ${DB_NAME} in project ${GCP_PROJECT_ID}"
	gcloud sql users delete ${DB_USER_NAME} --instance ${DB_NAME} --host=% --project=${GCP_PROJECT_ID} --quiet
}

function listusers(){
	log "Listing users for instance $DB_NAME in project ${GCP_PROJECT_ID} \n\n\n"
	gcloud sql users list --instance ${DB_NAME} --project=${GCP_PROJECT_ID}
	printf "\n\n\n"
}

function setuserpermissions()
{
	SQL_FILE_NAME="db_user_permissions.sql"
	LOCAL_SQL_FILE_NAME="${TMP_DIR}/${SQL_FILE_NAME}"

	log "Setting permissions for ${DB_USER_NAME}"
	log "Creating the sql file and sending to the bucket gs://${GCP_PROJECT_ID}/tmp/${SQL_FILE_NAME}"

	printf "use ${SCHEMA_NAME};\n" > ${LOCAL_SQL_FILE_NAME}
	printf "GRANT SELECT, EXECUTE ON ${SCHEMA_NAME}.* TO '${DB_USER_NAME}';\n" >> ${LOCAL_SQL_FILE_NAME}

	log "uploading the file ${LOCAL_SQL_FILE_NAME} to Cloud Storage"
	gsutil cp ${LOCAL_SQL_FILE_NAME} gs://${GCP_PROJECT_ID}/tmp/${SQL_FILE_NAME};

	SA_NAME=
	getdbserviceaccount

	if [[ -z "${SA_NAME}" ]]; then
		log "Could not find the service account name for the database ${DB_NAME}"
		failAndQuit
	fi

	# gsutil acl ch -u AllUsers:R gs://${GCP_PROJECT_ID}/tmp/${SQL_FILE_NAME};

	log "Setting bucket permissions for the Cloud Sql service account ${SA_NAME}"
	gsutil acl ch -u ${SA_NAME}:R gs://${GCP_PROJECT_ID};
	gsutil acl ch -u ${SA_NAME}:R gs://${GCP_PROJECT_ID}/tmp/${SQL_FILE_NAME};
	printf "Running the SQL file from the bucket \n"
	gcloud sql import sql ${DB_NAME} gs://${GCP_PROJECT_ID}/tmp/${SQL_FILE_NAME} --project=${GCP_PROJECT_ID} --quiet

	printf "Removing file from GCS bucket and local disk. \n"
	gsutil rm gs://${GCP_PROJECT_ID}/tmp/${SQL_FILE_NAME};
	rm ${LOCAL_SQL_FILE_NAME}
}

function getdbserviceaccount(){
	log "getting the Cloud Sql service account name"
	SA_NAME=$(gcloud sql instances describe ${DB_NAME} --project=${GCP_PROJECT_ID} --format="value(serviceAccountEmailAddress)")
	log "Cloud Sql service account name is: ${SA_NAME}"
}

function processScriptArgs(){
	log "Processing Script args"
	arg_count=${#ARGS[*]}

	for (( i=0; i<=$(( $arg_count -1 )); i++ ))
	do
		case ${ARGS[$i]} in
			-g | --project )		GCP_PROJECT_ID=${ARGS[$i + 1]}
							;;
			-d | --database )		DB_NAME=${ARGS[$i + 1]}
							;;
			-s | --schema )			SCHEMA_NAME=${ARGS[$i + 1]}
							;;
			-u | --user )			DB_USER_NAME=${ARGS[$i + 1]}
							;;
			-p | --password )		DB_USER_PASS=${ARGS[$i + 1]}
							;;
		esac
	done
}

function printHeaderVars(){
	log "GCP_PROJECT_ID: ${GCP_PROJECT_ID}"
	log "DB_NAME: ${DB_NAME}"
	log "SCHEMA_NAME: ${SCHEMA_NAME}"
	log "DB_USER_NAME: ${DB_USER_NAME}"
	log "DB_USER_PASS: ${DB_USER_PASS}"
}

function usage(){
	log "Example:"
	log " ${SCRIPT_NAME} --project my-gcp-project --database example-mysql --schema orders --user readonlyuser --password itsasecret"

	log "Options:"
	log " -g | --project - The name of the GCP project that contains the Cloud SQL instance."
	log " -d | --database - The name of the Cloud Sql instance to add the user to"
	log " -s | --schema - The name of the schema to give the user read only access to"
	log " -u | --user - The username for the user.  Defaults to readonlyuser"
	log " -p | --password - The users password."


	log "Standard Options: "
	log " -t | --tmp-dir	- Sets the temporary working directory, if omitted, ./tmp is used."
	log " -v | --verbose	- Print verbose output"
	log " -h | --help		- Prints the help for this script"
	log " -q | --quiet		- Suppress output"
}

function printHelp(){
	log "${SCRIPT_NAME}\n"
	log "Description:\n  -- Creates a read only user in a Cloud Sql instance."
	usage
}

main
