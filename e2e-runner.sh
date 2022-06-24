#!/usr/bin/env bash
# This script simulate the run of end-to-end tests by waiting for all 
# deployments in a namespace to be ready, then run the tests and report back 
# the status to the corresponding. Container labels are used to know the
# repository and commit sha to update the status with.

set -e

# mandatory variables
: ${E2E_FLOW?"Environment variable E2E_FLOW is undefined"}
: ${KUBERNETES_NAMESPACE?"Environment variable KUBERNETES_NAMESPACE is undefined"}

function run_e2e() {
  #
  # READINESS
  #############################################################################

  # wait for deployments to be created and available
  kubectl wait --namespace="$KUBERNETES_NAMESPACE" \
    --for=condition=Available \
    --selector "app in (backend, frontend)" \
    --timeout=300s \
    deployments

  # wait for readiness
  echo "Waiting for frontend pods to be ready..."
  kubectl wait --namespace="$KUBERNETES_NAMESPACE" \
    --for=condition=Ready \
    --selector "app in (backend, frontend)" \
    --timeout=300s \
    pods

  
  #
  # TESTING
  #############################################################################
  
  # run e2e, currently only a placeholder for the tests
  frontend_body=$(curl -s http://frontend)
  if [[ "$frontend_body" == *"feature enabled"* ]]
  then
    echo "e2e tests execution succeeded"
    state="success"
  else
    echo "e2e tests execution failed"
    state="failure"
  fi

  
  #
  # REPORTING
  #############################################################################

  # list all deployments
  local image_list=$(kubectl get deploy -o jsonpath='{.items[*].spec.template.spec.containers[*].image}')

  # set commit status in the corresponding repository/commit sha
  for image in $image_list
  do
    echo "Getting metadata for ${image}"
    local repository=$(docker inspect $image --format='{{index .Config.Labels "org.opencontainers.image.source"}}' | sed 's#https://github.com/##g')
    local commitSha=$(docker inspect $image --format='{{index .Config.Labels "org.opencontainers.image.revision"}}')
    if [[ "$repository" == "" ]] || [[ "$commitSha" == "" ]]
    then
      echo "Label org.opencontainers.image.source or org.opencontainers.image.revision are undefined. Skipping..."
      continue
    fi
    echo "Found ${repository} with sha ${commitSha}"

    grgate status set "$repository" \
      --commit "$commitSha" \
      --name "$E2E_FLOW" \
      --status completed \
      --state "$state"
  done
}

run_e2e


#
# CONTINUOUS TESTING
#############################################################################
while read -r event
do
  echo "Received event $event"
  run_e2e
done < <(kubectl get ev -n ${KUBERNETES_NAMESPACE} \
  --field-selector reason=Created,involvedObject.kind=Pod \
  --no-headers --watch-only)
