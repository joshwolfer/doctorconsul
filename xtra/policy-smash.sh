#!/bin/bash

i=0
while true; do
  if [[ "$i" -gt 1000 ]]; then
       exit 1
  fi
  consul acl policy create -name policy-$i -http-addr="http://127.0.0.1:8501"
  ((i++))
done

