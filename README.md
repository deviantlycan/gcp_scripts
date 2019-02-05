# gcp_scripts
A few handy scripts for use with Google Cloud

File Descriptions
* gcpListUsers.sh - This script reads the user accounts in GCP projects and lists all email addresses found and the projects that they have access to.

You can easily access these scripts from the Cloud Shell using wget.  Here is an example using gcpListUsers.sh:

```
wget https://raw.githubusercontent.com/deviantlycan/gcp_scripts/master/gcpListUsers.sh -O- | tr -d '\r' > gcpListUsers.sh
chmod 0755 gcpListUsers.sh
```
