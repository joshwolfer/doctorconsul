#!/bin/bash

set -e

source ./scripts/functions.sh

# GKE stuff goes here.

# gcloud auth login
# Make sure it uses the business account not personal, since chrome can be logged in as either. ugh.

# sudo apt-get install google-cloud-sdk-gke-gcloud-auth-plugin
# Need this to authenticate to GKE

gcloud config set project $GCP_PROJECT_ID

gcloud container clusters list

# ------------------------------------------
#      Create 4 beautiful GKE clusters
# ------------------------------------------

echo -e "${GRN}"
echo -e "=========================================="
echo -e "     Create 4 beautiful GKE clusters"
echo -e "==========================================${NC}"

# These get created as "GKE autopilot" clusters, which evidently are not supported on Consul yet. Supposed to be in Aug 2023.
# Gonna pause this project until they're supported.

create_gke_cluster "$KDC3"
create_gke_cluster "$KDC3_P1"
create_gke_cluster "$KDC4"
create_gke_cluster "$KDC4_P1"

wait     # wait for all background tasks to complete

# If for some reason the GKE contexts aren't created or are lost, these will recreate the contexts in the kubeconfig
#
# gcloud container clusters get-credentials $KDC3 --region $GCP_REGION --project $GCP_PROJECT_ID
# gcloud container clusters get-credentials $KDC3_P1 --region $GCP_REGION --project $GCP_PROJECT_ID
# gcloud container clusters get-credentials $KDC4 --region $GCP_REGION --project $GCP_PROJECT_ID
# gcloud container clusters get-credentials $KDC4_P1 --region $GCP_REGION --project $GCP_PROJECT_ID

# ------------------------------------------
# Rename Kube Contexts to match Doctor Consul DC3 / DC4
# ------------------------------------------

echo -e "${GRN}"
echo -e "=========================================="
echo -e "  Rename GKE Kube Contexts for DC3 / DC4"
echo -e "==========================================${NC}"

# Call the function with different cluster names
update_gke_context "$KDC3"
update_gke_context "$KDC3_P1"
update_gke_context "$KDC4"
update_gke_context "$KDC4_P1"




