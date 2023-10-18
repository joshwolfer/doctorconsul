#!/bin/bash

# ==========================================
#        JWT Auth configuration
# ==========================================

# OIDC is setup with Auth0 and grants read to the Baphomet services in the Proj1 Admin Partition.

  # Enable JWT auth in Consul  - (Coming soon)

  # consul acl auth-method create -type jwt \
  #   -name jwt \
  #   -max-token-ttl=30m \
  #   -config=@./docker-configs/auth/oidc-auth.json

  # consul acl binding-rule create \
  #   -method=auth0 \
  #   -bind-type=role \
  #   -bind-name=team-proj1-rw \
  #   -selector='proj1 in list.groups'