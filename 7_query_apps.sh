#!/bin/bash
set -euo pipefail

. utils.sh

announce "Validating that the deployments are functioning as expected."

set_namespace $TEST_APP_NAMESPACE_NAME

init_url=$($cli describe service test-app-summon-init | grep 'LoadBalancer Ingress' | awk '{ print $3 }'):8080
sidecar_url=$($cli describe service test-app-summon-sidecar | grep 'LoadBalancer Ingress' | awk '{ print $3 }'):8080

echo -e "Adding entry to the init app\n"
curl \
  -d '{"name": "Mr. Init"}' \
  -H "Content-Type: application/json" \
  $init_url/pet

echo -e "Adding entry to the sidecar app\n"
curl \
  -d '{"name": "Mr. Sidecar"}' \
  -H "Content-Type: application/json" \
  $sidecar_url/pet

echo -e "Remember that they are both using the same DB backend...\n"

echo -e "Querying init app\n"
curl $init_url/pets

echo -e "\n\nQuerying sidecar app\n"
curl $sidecar_url/pets
