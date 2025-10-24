#!/bin/sh

# https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/run-scripts
if [ -n "${GITHUB_WORKSPACE}" ]; then
	# Cleanup local workspace folder
	rm -rf "$GITHUB_WORKSPACE" && mkdir -p "$GITHUB_WORKSPACE"
fi

# Remove stopped containers, unused networks and images, and build cache older than 24h
docker system prune -af --filter "until=24h"
