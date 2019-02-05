#!/bin/bash

PARAM_LIMIT=
PROJECT=
OUTPUT_FILE="gcpusers.txt"
PROJECT_LIST=
START_TIME=
CSV_OUTPUT=false
QUIET=false

# Reads the cvommand line parameters
while [ "$1" != "" ]
do
	case $1 in
		-L | --limit )	  shift
								PARAM_LIMIT=$1
								;;
		-p | --project )	shift
								PROJECT=$1
								;;
		-f | --file )	   shift
								OUTPUT_FILE=$1
								;;
		-c | --csv )			CSV_OUTPUT=true
								;;
		-v | --verbose )		set -x # echo on
								;;
		-q | --quiet )		  QUIET=true
								;;
		-h | --help )		   printhelp
								exit
								;;
		* )					 printhelp
								exit 1
	esac
	shift
done

# Main entry point
function main(){
	initFiles
	printHeader

	if [ -z "$PROJECT" ]
	then
		getProjectList
		processProjectList
	else
		processProject
	fi
	
	printOutput
	saveFile
	cleanupFiles
	printFooter
}

# Prints usage information
function usage()
{
	printf "Usage: gcpListUsers.sh [-L | --limit] [-p | --project] [-f | --file] [-v | --verbose] [-h | --help]\n\n"
	printf "\t -L | --limit	 - Limit to only the first N projects found\n"
	printf "\t -p | --project   - Limit to only the specified project\n"
	printf "\t -f | --file	  - File name to save the output to\n"
	printf "\t -c | --csv	   - Save the output as a CSV file\n"
	printf "\t -v | --verbose   - Print verbose output\n"
	printf "\t -h | --help	  - Prints the help for this script\n"
	printf "\nExample:\n	gcpListUsers.sh --limit 5 --project my_gcp_project --file gcpUsers.csv --csv\n"
}

function printhelp()
{
	printf "Description: \n  This script reads the user accounts in GCP projects and lists all email addresses found and the projects that they have access to. \n\n"
	usage
}

# Initializes the files
function initFiles(){
	if [ $CSV_OUTPUT == 'true' ]; then
		if [ $OUTPUT_FILE == 'gcpusers.txt' ]; then
			OUTPUT_FILE="gcpusers.csv"
		fi
	fi
	touch gcpusers.tmp
}

# Prints out the start time and the parameters affecting how this script will run
function printHeader(){
	if [ $QUIET == 'false' ]; then
		printf "\n======================\n"
		START_TIME=`date +%s`
		printf "Start time: $(date)\n"
		printf "Project Limit: ${PARAM_LIMIT}\n"
		printf "Project: ${PROJECT}\n"
		printf "Output file: ${OUTPUT_FILE}\n"
		printf "CSV Output: ${CSV_OUTPUT}\n"
		printf "\n======================\n"
	fi
}

# Prints a summary of the script execution.
function printFooter(){
	if [ $QUIET == 'false' ]; then
		END_TIME=`date +%s`
		TOTAL_RUN_TIME=$((END_TIME-START_TIME))
		printf "End Time: $(date)\n"
		printf "Total Run Time: ${TOTAL_RUN_TIME} seconds.\n"
		printf "Process Complete \n"
	fi
	printf "\n======================\n"
}

# Reads a list of all projects that the invoker has access to
function getProjectList(){
	if [ $QUIET == 'false' ]; then
		printf "Reading all projects\n"
	fi
	PROJECT_LIST=$(gcloud projects list --format="get(projectId)")
}

# Processes the list of projects
function processProjectList(){
	if [ $QUIET == 'false' ]; then
		if [ -z "$PARAM_LIMIT" ]
		then
			printf "Processing all projects.\n"
		else
			printf "Processing the first ${PARAM_LIMIT} projects.\n"
		fi
	fi

	x=1
	for PROJECT in $PROJECT_LIST
	do
		processProject
		if [ $x -eq $(( $PARAM_LIMIT )) ]
		then
			break
		fi
		x=$(( $x + 1 ))
	done
}

# Reads user information for a single project (in the variable $PROJECT)
function processProject(){
	FILTER=".bindings[] | select (.members) | .members[] | select (. | startswith(\"user:\")) | ltrimstr(\"user:\")"	
	if [ $QUIET == 'false' ]; then
		printf "Getting users from project: $PROJECT\n"
	fi

	# gcloud projects get-iam-policy ${PROJECT} --format=json | jq --raw-output "${FILTER}" >> gcpusers.tmp
	EMAIL_LIST=$(gcloud projects get-iam-policy ${PROJECT} --format=json | jq --raw-output "${FILTER}")
	for EMAIL in $EMAIL_LIST; do
		if [ $CSV_OUTPUT == 'true' ]; then
			grep -q "^${EMAIL}" gcpusers.tmp && sed -i "/${EMAIL}.*/ s/$/, ${PROJECT}/" gcpusers.tmp || printf "${EMAIL},${PROJECT}\n" >> gcpusers.tmp
		else
			grep -q "^${EMAIL}" gcpusers.tmp && sed -i "/${EMAIL}.*/ s/$/, ${PROJECT}/" gcpusers.tmp || printf "${EMAIL}\t\tProjects: ${PROJECT}\n" >> gcpusers.tmp
		fi
	done
}

# Saves the result to an output file.
function saveFile(){
	if [ $QUIET == 'false' ]; then
		printf "\nSaving to file ${OUTPUT_FILE}\n"
		if [ $CSV_OUTPUT == 'true' ]; then
			printf "email, project, project, project\n" > ${OUTPUT_FILE}
		fi
	fi
	cat gcpusers.tmp | sort --unique >> ${OUTPUT_FILE}
}

# removes temporary files.
function cleanupFiles(){
	rm gcpusers.tmp
}

# Prints the final output to the screen
function printOutput(){
	if [ $QUIET == 'false' ]; then
		printf "\n===== Users List =====\n"
		cat gcpusers.tmp | sort --unique
		printf "\n======================\n"
	fi
}

main
