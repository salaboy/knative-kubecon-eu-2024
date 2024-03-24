#!/usr/bin/env bash

set -o errexit
set -o nounset

REGISTRY_PORT=5000

if [[ -z "${DEMO_DOMAIN}" ]]; then
  echo "Update DEMO_DOMAIN environment variable in the .envrc file"
  exit 1
fi

function create_kind_cluster() {
  local version=${1:-1.28.7}

  # 1. Create registry container unless it already exists
  local reg_name="${DEMO_DOMAIN}"
  local reg_port="${REGISTRY_PORT}"
  if [ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]; then
    docker run \
      -d --restart=always -p "127.0.0.1:${reg_port}:${reg_port}" --network bridge --name "${reg_name}" \
      registry:2
  fi

  config=$(mktemp)
cat <<EOF >"$config"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."${reg_name}:${reg_port}"]
    endpoint = ["http://${reg_name}:${reg_port}"]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
    endpoint = ["https://mirror.gcr.io"]
nodes:
- role: control-plane
  image: kindest/node:v${version}
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  image: kindest/node:v${version}
- role: worker
  image: kindest/node:v${version}
EOF

  kind delete cluster
  kind create cluster --config "$config"

  if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}")" = 'null' ]; then
    docker network connect "kind" "${reg_name}"
  fi

  # 5. Document the local registry
  # https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "${reg_name}:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
}

function install_certmanager() {
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
}
function install_istio() {
  # Setup Istio
  kubectl apply -f https://raw.githubusercontent.com/knative-sandbox/net-istio/main/third_party/istio-latest/istio-kind-no-mesh/istio.yaml
  kubectl patch deployment -n istio-system istio-ingressgateway -p '
  {
    "spec": {
      "template": {
        "spec": {
          "nodeSelector": {
            "ingress-ready": "true"
          },
          "tolerations": [
            {
              "key": "node-role.kubernetes.io/control-plane",
              "operator": "Equal",
              "effect": "NoSchedule"
            },
            {
              "key": "node-role.kubernetes.io/master",
              "operator": "Equal",
              "effect": "NoSchedule"
            }
          ]
        }
      }
    }
  }'

  kubectl patch deployment -n istio-system istio-ingressgateway -p '
  {
    "spec":{
      "template": {
        "spec":{
          "containers":[{
            "name":"istio-proxy",
            "ports":[
              {"containerPort": 8080, "hostPort": 80},
              {"containerPort": 8443, "hostPort": 443}
            ]
          }]
        }
      }
    }
   }'
}

function install_serving() {
  kubectl apply -f https://github.com/knative/serving/releases/latest/download/serving-crds.yaml
  kubectl wait --for condition=established --timeout=60s --all crd
  kubectl apply -f https://github.com/knative/serving/releases/latest/download/serving-core.yaml

  kubectl wait --namespace knative-serving \
               --all \
               --for=condition=ready pod \
               --timeout=90s

  kubectl patch configmap/config-network \
    --namespace knative-serving \
    --type merge \
    --patch '{"data":{
      "ingress.class":"istio.ingress.networking.knative.dev",
      "autocreate-cluster-domain-claims":"true",
      "external-domain-tls": "enabled"
    }}'

  kubectl patch configmap/config-domain \
    --namespace knative-serving \
    --type merge \
    --patch "{\"data\":{\"${DEMO_DOMAIN}\":\"\"}}"

  kubectl patch configmap/config-deployment \
    --namespace knative-serving \
    --type merge \
    --patch "{\"data\":{
      \"registries-skipping-tag-resolving\": \"kind.local,ko.local,dev.local,${DEMO_DOMAIN}:${REGISTRY_PORT}\"
  }}"

  kubectl apply -f https://github.com/knative-extensions/net-istio/releases/latest/download/net-istio.yaml

  kubectl wait --namespace knative-serving \
               --all \
               --for=condition=ready pod \
               --timeout=90s

  kubectl apply -f https://github.com/knative-extensions/net-certmanager/releases/latest/download/net-certmanager.yaml

  kubectl wait --namespace knative-serving \
               --all \
               --for=condition=ready pod \
               --timeout=90s

  # Self signed issuer
  kubectl apply -f https://raw.githubusercontent.com/knative/serving/main/test/config/externaldomaintls/certmanager/selfsigned/issuer.yaml
  kubectl apply -f https://raw.githubusercontent.com/knative/serving/main/test/config/externaldomaintls/certmanager/selfsigned/config-certmanager.yaml
}

set -o verbose

create_kind_cluster
install_istio
install_certmanager
install_serving
