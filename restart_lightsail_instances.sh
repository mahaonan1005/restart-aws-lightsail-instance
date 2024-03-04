#!/bin/bash

# Assumes you have AWS CLI configured and jq installed

# Start time measurement
start_time=$(date +%s)

# Fetch and delete existing static IPs 
aws lightsail get-static-ips --query 'staticIps[*].[name]' --output text | while read -r ip_name
do
  echo "Deleting $ip_name..."
  aws lightsail release-static-ip --static-ip-name $ip_name
done

# Get instance names
instance_names=$(aws lightsail get-instances | jq -r '.instances[] | .name')

# Stop instances in parallel
echo "$instance_names" | xargs --no-run-if-empty -P 8 -I {} aws lightsail stop-instance --instance-name {}

# Start instances in parallel
echo "$instance_names" | xargs --no-run-if-empty -P 8 -I {} aws lightsail start-instance --instance-name {}

# Display instance names and new public IP addresses
aws lightsail get-instances --query "instances[*].[name, publicIpAddress]" --output json | jq -r '.[] | @tsv' | sort

# End time measurement
end_time=$(date +%s)

# Calculate and display elapsed time
elapsed_time=$(( end_time - start_time ))
echo "Total execution time: $elapsed_time seconds" 
