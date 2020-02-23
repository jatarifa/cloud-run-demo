#!/bin/bash

gcloud container clusters create poc-cluster \
  --cluster-version latest \
  --machine-type=n1-standard-4 \
  --num-nodes 3 \
  --zone=us-central1-b \
  --enable-autorepair \
  --scopes cloud-platform
  
gcloud container clusters get-credentials poc-cluster \
  --zone=us-central1-b --project=poc-lanzarote

kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole=cluster-admin \
  --user=$(gcloud config get-value core/account)

export ISTIO_VERSION=1.4.5
curl -L https://istio.io/downloadIstio | sh -

cd istio-1.4.5

kubectl create namespace istio-system

helm template install/kubernetes/helm/istio-init \
  --name istio-init \
  --namespace istio-system | kubectl apply -f -

kubectl -n istio-system wait \
  --for=condition=complete job \
  --all

helm template --namespace=istio-system \
  --set prometheus.enabled=false \
  --set mixer.enabled=false \
  --set mixer.policy.enabled=false \
  --set mixer.telemetry.enabled=false \
  --set pilot.sidecar=false \
  --set pilot.resources.requests.memory=128Mi \
  --set galley.enabled=false \
  --set global.useMCP=false \
  --set security.enabled=false \
  --set global.disablePolicyChecks=true \
  --set sidecarInjectorWebhook.enabled=false \
  --set global.proxy.autoInject=disabled \
  --set global.omitSidecarInjectorConfigMap=true \
  --set gateways.istio-ingressgateway.autoscaleMin=1 \
  --set gateways.istio-ingressgateway.autoscaleMax=2 \
  --set pilot.traceSampling=100 \
  --set global.mtls.auto=false \
  install/kubernetes/helm/istio | kubectl apply -f -

helm template --namespace=istio-system \
  --set gateways.custom-gateway.autoscaleMin=1 \
  --set gateways.custom-gateway.autoscaleMax=2 \
  --set gateways.custom-gateway.cpu.targetAverageUtilization=60 \
  --set gateways.custom-gateway.labels.app='cluster-local-gateway' \
  --set gateways.custom-gateway.labels.istio='cluster-local-gateway' \
  --set gateways.custom-gateway.type='ClusterIP' \
  --set gateways.istio-ingressgateway.enabled=false \
  --set gateways.istio-egressgateway.enabled=false \
  --set gateways.istio-ilbgateway.enabled=false \
  --set global.mtls.auto=false \
  install/kubernetes/helm/istio \
  -f install/kubernetes/helm/istio/example-values/values-istio-gateways.yaml \
  | sed -e "s/custom-gateway/cluster-local-gateway/g" -e "s/customgateway/clusterlocalgateway/g" | kubectl apply -f -

kubectl apply --selector knative.dev/crd-install=true \
  --filename https://github.com/knative/serving/releases/download/v0.12.0/serving.yaml \
  --filename https://github.com/knative/eventing/releases/download/v0.12.0/eventing.yaml

kubectl apply --filename https://github.com/knative/serving/releases/download/v0.12.0/serving.yaml \
  --filename https://github.com/knative/eventing/releases/download/v0.12.0/eventing.yaml \
  --filename https://github.com/google/knative-gcp/releases/download/v0.12.0/cloud-run-events.yaml