#!/bin/bash

# This script is run inside the docker-compose project.
# It waits for the frost server to be initialized, indicating that the desired tables will be added to the db.
# Once this occurs, we can then apply the SQL indices.

# Wait for the wqp-frost service to be ready
echo "Waiting for wqp-frost to be ready..."

# Define a max number of retries and delay time
MAX_RETRIES=30
RETRY_INTERVAL=3
RETRY_COUNT=0

# Check for wqp-frost service readiness
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker exec wqp-frost curl -s --head http://wqp-frost:8080/FROST-Server; then
        echo "wqp-frost is ready."
        break
    else
        echo "wqp-frost is not ready yet. Retrying in $RETRY_INTERVAL seconds..."
        RETRY_COUNT=$((RETRY_COUNT + 1))
        sleep $RETRY_INTERVAL
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "wqp-frost did not become ready in time. Exiting."
    exit 1
fi

# After wqp-frost is initialized, apply the SQL statements from the file
echo "Running SQL commands to create indices in the database..."

# Ensure the SQL file exists in the container
if [ ! -f indices.sql ]; then
    echo "SQL file 'indices.sql' not found. Exiting."
    exit 2
fi

# Execute the SQL commands using psql inside the database container
docker exec -i wqp-database psql -U sensorthings -d sensorthings < indices.sql

# Check if the SQL execution was successful
if [ $? -eq 0 ]; then
    echo "SQL commands executed successfully."
else
    echo "Failed to execute SQL commands. Exiting."
    exit 3
fi
