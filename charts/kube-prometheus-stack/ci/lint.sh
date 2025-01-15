#!/usr/bin/env bash

set -euo pipefail

{
    SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

    cd "${SCRIPT_DIR}/../"

    cp charts/crds/files/crds.tar.xz /tmp/crds.tar.xz

    ./hack/update_crds.sh
    if ! git diff "$GITHUB_SHA" --color=always --exit-code; then
      echo "Please run ./hack/update_crds.sh"

      echo "Diff:"
      ls -l /tmp/crds.tar.xz charts/crds/files/crds.tar.xz
      echo "Diff:"
      shasum -a 256 /tmp/crds.tar.xz charts/crds/files/crds.tar.xz
      echo "Diff:"
      tar tvf /tmp/crds.tar.xz
      echo "-----"
      tar tvf charts/crds/files/crds.tar.xz
      echo "Diff:"

      git diff --color=always <(
        strings /tmp/crds.tar.xz
      ) <(
        strings charts/crds/files/crds.tar.xz
      )
      echo "Diff:"

      git diff --color=always <(
        xxd /tmp/crds.tar.xz
      ) <(
        xxd charts/crds/files/crds.tar.xz
      )

      exit 1
    fi

    cd hack

    export PIP_DISABLE_PIP_VERSION_CHECK=1

    python3 -m venv venv
    # shellcheck disable=SC1091
    source venv/bin/activate

    pip3 install -r requirements.txt

    go install -a github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest
    PATH="$(go env GOPATH)/bin:$PATH"
    export PATH

    ./sync_prometheus_rules.py
    if ! git diff "$GITHUB_SHA" --color=always --exit-code; then
      echo "Changes inside rules are not supported!"
      echo "Please go into the ./hack/ directory and run ./sync_prometheus_rules.py"
      exit 1
    fi

    ./sync_grafana_dashboards.py
    if ! git diff "$GITHUB_SHA" --color=always --exit-code; then
      echo "Changes inside dashboards are not supported!"
      echo "Please go into the ./hack/ directory and run ./sync_grafana_dashboards.py"
      exit 1
    fi

    rm -rf ./venv ./*.git
} 2>&1
