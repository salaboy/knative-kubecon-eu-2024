#!/usr/bin/env bash

set -o errexit
set -o xtrace

go install sigs.k8s.io/kind@v0.22.0
go install knative.dev/func@main
