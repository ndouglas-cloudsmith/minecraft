#!/bin/bash

# Define the base name for the namespaces
BASE_NAME="meghan"

# Initialize a counter
i=1

# Start an infinite loop
while true
do
    # Construct the namespace name
    NAMESPACE_NAME="${BASE_NAME}${i}"

    # Use 'kubectl create namespace' to create the namespace
    # The '|| true' ensures the script doesn't stop if the kubectl command fails
    echo "Attempting to create namespace: ${NAMESPACE_NAME}..."
    kubectl create namespace "${NAMESPACE_NAME}" || echo "Error creating namespace ${NAMESPACE_NAME}"

    # Increment the counter for the next iteration
    i=$((i + 1))

    # Wait for 3 seconds before the next creation
    sleep 3
done

# The script will only reach this point if the loop is somehow broken
echo "Script finished."
