#!/bin/bash
set -euo pipefail

. utils.sh

announce "Loading Conjur policy."

pushd policy
  mkdir -p ./generated

  sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" ./templates/cluster-authn-svc-def.template.yml > ./generated/cluster-authn-svc.yml

  sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" ./templates/project-authn-def.template.yml |
    sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    sed -e "s#{{ TEST_APP_NAME }}#$TEST_APP_NAME#g" > ./generated/project-authn.yml

  sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" ./templates/app-identity-def.template.yml |
    sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    sed -e "s#{{ TEST_APP_NAME }}#$TEST_APP_NAME#g" > ./generated/app-identity.yml

  sed -e "s#{{ TEST_APP_NAME }}#$TEST_APP_NAME#g" ./templates/app-access-def.template.yml > ./generated/app-access.yml
popd


set_namespace $CONJUR_NAMESPACE_NAME
conjur_cli_pod=$(get_conjur_cli_pod_name)

if [ $PLATFORM = 'kubernetes' ]; then
  kubectl cp ./policy $conjur_cli_pod:/policy
elif [ $PLATFORM = 'openshift' ]; then
  oc rsync ./policy $conjur_cli_pod:/
fi

$cli exec $conjur_cli_pod -- conjur authn login -u admin -p $CONJUR_ADMIN_PASSWORD

POLICY_FILE_LIST="policy/users.yml
policy/generated/project-authn.yml
policy/generated/cluster-authn-svc.yml
policy/generated/app-identity.yml
policy/generated/app-access.yml"

for i in $POLICY_FILE_LIST; do
  echo "Loading policy $i..."
  if [ $CONJUR_VERSION = '4' ]; then
    $cli exec $conjur_cli_pod -- conjur policy load --as-group security_admin /$i
  elif [ $CONJUR_VERSION = '5' ]; then
    $cli exec $conjur_cli_pod -- conjur policy load root $i
  fi
done
    
$cli exec $conjur_cli_pod -- rm -rf ./policy

echo "Conjur policy loaded."

password=$(openssl rand -hex 12)

$cli exec $conjur_cli_pod -- conjur variable values add "secrets/db-password" $password

announce "Added DB password value: $password"

$cli exec $conjur_cli_pod -- conjur authn logout

set_namespace $TEST_APP_NAMESPACE_NAME
