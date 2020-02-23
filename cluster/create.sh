#!/bin/bash

set -x

gcloud services enable \
     cloudapis.googleapis.com \
     container.googleapis.com \
     pubsub.googleapis.com \
     containerregistry.googleapis.com

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
rm -rf istio-$ISTIO_VERSION
curl -L https://istio.io/downloadIstio | sh -
cd istio-$ISTIO_VERSION

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
--filename https://github.com/knative/eventing/releases/download/v0.12.0/eventing.yaml


export PROJECT_ID=poc-lanzarote
gcloud projects add-iam-policy-binding $PROJECT_ID \
	--member=serviceAccount:knative-source@$PROJECT_ID.iam.gserviceaccount.com \
	--role roles/pubsub.editor
rm -rf knative-source.json
gcloud iam service-accounts keys create knative-source.json \
	--iam-account=knative-source@$PROJECT_ID.iam.gserviceaccount.com
kubectl -n default create secret generic google-cloud-key \
 --from-file=key.json=knative-source.json
kubectl apply -f https://github.com/google/knative-gcp/releases/download/v0.9.0/cloud-run-events.yaml


gcloud pubsub topics create testing
cat <<EOF | kubectl apply -f -
apiVersion: pubsub.cloud.run/v1alpha1
kind: PullSubscription
metadata:
  name: testing-source
spec:
  topic: testing
  sink:
    apiVersion: v1
    kind: Service
    name: event-display
  project: poc-lanzarote
  secret:
    name: google-cloud-key
    key: key.json
EOF

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: event-display
spec:
  selector:
    matchLabels:
      app: event-display
  template:
    metadata:
      labels:
        app: event-display
    spec:
      containers:
      - name: user-container
        image: gcr.io/knative-releases/github.com/knative/eventing-contrib/cmd/event_display
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: event-display
spec:
  selector:
    app: event-display
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
EOF


export TOPIC_NAME=testing
gcloud pubsub topics publish $TOPIC_NAME --message='{"msg": "Hello Knative"}'
kubectl logs --selector app=event-display -c user-container