#!/bin/bash

# Function to generate a random CVE-like ID (e.g., CVE-2023-12345)
generate_random_cve() {
    # 1. Generate a random year (e.g., between 2000 and the current year)
    CURRENT_YEAR=$(date +%Y)
    
    # Calculate a random year between 2000 and the current year
    RANDOM_YEAR_OFFSET=$((RANDOM % (CURRENT_YEAR - 2000 + 1)))
    YEAR=$((2000 + RANDOM_YEAR_OFFSET))

    # 2. Generate the sequential part (5 or 6 random digits)
    SEQUENTIAL_PART=$((RANDOM + 10000))

    # Combine them into the CVE format
    echo "CVE-${YEAR}-${SEQUENTIAL_PART}"
}

# Start an infinite loop
while true
do
    # 1. Generate the random CVE-like ID
    RAW_NAME=$(generate_random_cve)

    # 2. CONVERT TO LOWERCASE to satisfy Kubernetes RFC 1123 label requirements
    NAMESPACE_NAME=$(echo "$RAW_NAME" | tr '[:upper:]' '[:lower:]')

    # Use 'kubectl create namespace' to create the namespace
    echo "Attempting to create namespace: ${NAMESPACE_NAME}..."
    kubectl create namespace "${NAMESPACE_NAME}" || echo "Error creating namespace ${NAMESPACE_NAME}"

    # Wait for 3 seconds before the next creation
    sleep 3
done

# The script will only reach this point if the loop is somehow broken
echo "Script finished."
