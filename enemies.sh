#!/bin/bash

# Function to generate a random CVE-like ID (e.g., CVE-2023-12345)
# Note: This is NOT a real, registered CVE ID, only a string matching the format.
generate_random_cve() {
    # 1. Generate a random year (e.g., between 2000 and the current year)
    CURRENT_YEAR=$(date +%Y)
    
    # Calculate a random year between 2000 and the current year
    # Generates a number between 0 and (CURRENT_YEAR - 2000)
    RANDOM_YEAR_OFFSET=$((RANDOM % (CURRENT_YEAR - 2000 + 1)))
    YEAR=$((2000 + RANDOM_YEAR_OFFSET))

    # 2. Generate the sequential part (e.g., 4 to 6 random digits)
    # The '10000' ensures it's at least 5 digits long (10000 to 42767)
    # The '32768' is the max value of RANDOM on most systems, so we add 10000 
    # to guarantee at least 5 digits (it will be 5 or 6 digits total)
    SEQUENTIAL_PART=$((RANDOM + 10000))

    # Combine them into the CVE format
    echo "CVE-${YEAR}-${SEQUENTIAL_PART}"
}

# Start an infinite loop
while true
do
    # Generate the random CVE-like ID
    NAMESPACE_NAME=$(generate_random_cve)

    # Use 'kubectl create namespace' to create the namespace
    # The '|| true' ensures the script doesn't stop if the kubectl command fails
    echo "Attempting to create namespace: ${NAMESPACE_NAME}..."
    kubectl create namespace "${NAMESPACE_NAME}" || echo "Error creating namespace ${NAMESPACE_NAME}"

    # Wait for 3 seconds before the next creation
    sleep 3
done

# The script will only reach this point if the loop is somehow broken
echo "Script finished."
