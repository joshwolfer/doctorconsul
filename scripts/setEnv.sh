
#!/bin/bash

set -e

export RED='\033[1;31m'
export BLUE='\033[1;34m'
export DGRN='\033[0;32m'
export GRN='\033[1;32m'
export YELL='\033[0;33m'
export NC='\033[0m'

export DC1="http://127.0.0.1:8500"
export DC2="http://127.0.0.1:8501"
export DC3="https://127.0.0.1:8502"
export DC4="https://127.0.0.1:8503"
export DC5=""
export DC6=""

export KDC3="web1"
export KDC3_P1="api1"
export KDC4="k3d-dc4"
export KDC4_P1="k3d-dc4-p1"

export FAKESERVICE_VER="v0.25.0"

export HELM_CHART_VER=""