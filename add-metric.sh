#!/bin/bash

# run this file as root on master machine
# e.g. (replace HOSTNAME with your chosen hostname):
#   ssh root@HOSTNAME 'bash -s HOSTNAME' < add-metric.sh
# (or copy/checkout the script there and just run 'bash add-metric.sh HOSTNAME')

if [ "$#" -eq 1 ]
then
  hostname="$1"
else
  hostname="$HOSTNAME"
fi

# create the metric pods
# ----------------------

# Switch to the openshift-infra project
oc project openshift-infra

# Create a metrics-deployer service account
oc create -f - <<API
apiVersion: v1
kind: ServiceAccount
metadata:
  name: metrics-deployer
secrets:
- name: metrics-deployer
API

# Grante the edit permission for the openshift-infra project
oadm policy add-role-to-user \
    edit system:serviceaccount:openshift-infra:metrics-deployer

# Grante the cluster-reader permission for the Heapster service account
oadm policy add-cluster-role-to-user \
    cluster-reader system:serviceaccount:openshift-infra:heapster

# Using Generated Self-Signed Certificates
oc secrets new metrics-deployer nothing=/dev/null

# Deploying metrics without Persistent Storage
wget https://raw.githubusercontent.com/openshift/origin-metrics/master/metrics.yaml
oc new-app -f metrics.yaml -p USE_PERSISTENT_STORAGE=false -p HAWKULAR_METRICS_HOSTNAME=$hostname

# Exit
exit

# get the openshift token
# -----------------------

secret=`oc get -n management-infra sa/management-admin --template='{{range .secrets}}{{printf "%s\n" .name}}{{end}}' | grep management-admin-token | head -n 1`; oc get -n management-infra secrets $secret --template='{{.data.token}}' | base64 -d > token.txt; cat token.txt; echo

# cleaning up
# -----------

oc delete all --selector="metrics-infra"
oc delete sa --selector="metrics-infra"
oc delete templates --selector="metrics-infra"
oc delete secrets --selector="metrics-infra"
oc delete pvc --selector="metrics-infra"
oc delete sa metrics-deployer
oc delete secret metrics-deployer

# check all
# ---------

# watch the metric pods until all are running
oc get pods --all-namespaces -w

# wait for casndra, hawkular and heapster pods to run then test
curl -X GET https://$hostname/hawkular/metrics/status --insecure
