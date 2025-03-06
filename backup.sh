#!/bin/bash

# Define the S3 bucket for the backup
S3_BUCKET="s3://jenkins-backup-buctest1/backup/"
AWS_REGION="us-east-1"

# Define the path to store the backup locally (on Jenkins Node)
BACKUP_DIR="/tmp/backup_my_first_job"

# Create a directory for backup if it doesn't exist
mkdir -p $BACKUP_DIR

# Define the Jenkins job name
JENKINS_JOB="my-first-job"  # Change this to your job name

# Fetch the list of build numbers (sorted by most recent) from Jenkins API
BUILD_LIST_RAW=$(curl -s -u remya:1104e4134dcfd14d14f5e6acd23ee5833d "http://3.93.59.32:8080/job/$JENKINS_JOB/api/json?tree=builds%5Bnumber%5D")

#  Print the raw response for debugging
echo "Raw response from Jenkins API: $BUILD_LIST_RAW"

# Check if the raw response is empty or not
if [ -z "$BUILD_LIST_RAW" ]; then
  echo "Error: The API response is empty or not accessible. Please check the Jenkins API URL."
  exit 1
fi

# Extract build numbers using jq and check if we got any build numbers
#BUILD_LIST=$(echo "$BUILD_LIST_RAW" | jq -r '.builds[].number')
BUILD_LIST=$(echo "$BUILD_LIST_RAW" | jq -r '.builds[].number' | head -n 2)
# Check if we successfully fetched build numbers
if [ -z "$BUILD_LIST" ]; then
  echo "No build numbers found. Please verify the structure of the Jenkins API response."
  exit 1
fi

# Print the parsed build numbers
echo "Parsed build numbers: $BUILD_LIST"

# Loop through the build numbers and download artifacts
for BUILD_NUMBER in $BUILD_LIST; do
  # Create a directory for this build backup
  BUILD_DIR="$BACKUP_DIR/build_$BUILD_NUMBER"
  mkdir -p $BUILD_DIR

  # Define the artifact URL
  ARTIFACT_URL="http://3.93.59.32:8080/job/$JENKINS_JOB/$BUILD_NUMBER/artifact/*zip*/archive.zip"
  ARTIFACT_FILE="$BUILD_DIR/archive.zip"

  # Print the download URL for debugging
  echo "Downloading artifact for build #$BUILD_NUMBER from URL: $ARTIFACT_URL"
  
  # Fetch artifact
  curl -s -u remya:1104e4134dcfd14d14f5e6acd23ee5833d "$ARTIFACT_URL" -o "$ARTIFACT_FILE"

  # Check if the artifact was downloaded successfully and is a valid zip file
  if [ ! -f "$ARTIFACT_FILE" ]; then
    echo "Error: Failed to download artifact for build #$BUILD_NUMBER"
    continue
  fi
  
  # Check if the downloaded file is a valid zip
  if ! unzip -tq "$ARTIFACT_FILE" > /dev/null; then
    echo "Error: Invalid zip file for build #$BUILD_NUMBER, skipping extraction."
    continue
  fi

  # Unzip the downloaded artifacts
  unzip -o "$ARTIFACT_FILE" -d "$BUILD_DIR"
done

# Show the files in the backup directory before upload
echo "Files in backup directory before upload:"
ls -l $BACKUP_DIR

# Upload the backup directory to AWS S3
echo "Starting backup upload to S3..."
aws s3 cp $BACKUP_DIR $S3_BUCKET --recursive --region $AWS_REGION

# Check the result of the upload
if [ $? -eq 0 ]; then
  echo "Backup to AWS S3 was successful!"
else
  echo "Backup to AWS S3 failed!"
  exit 1
fi
