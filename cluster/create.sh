#!/bin/bash

gcloud compute networks create custom-network1 \                                                                             ✔  10045  15:10:16
    --subnet-mode custom

gcloud compute networks subnets create subnet-us-central1-192 \
   --network custom-network1 \
   --region us-central1 \
   --range 192.168.1.0/24

gcloud compute firewall-rules create allow-ssh \
    --network custom-network1 \
    --source-ranges 35.235.240.0/20 \
    --allow tcp:22

gcloud compute routers create nat-router \
    --network custom-network1 \
    --region us-central1

gcloud compute routers nats create nat-config \
    --router-region us-central1 \
    --router nat-router \
    --nat-all-subnet-ip-ranges \
    --auto-allocate-nat-external-ips

gcloud compute addresses list

gcloud beta container clusters create "cluster-1" \
  --project "poc-lanzarote" \
  --zone "us-central1-c" \
  --cluster-version "latest" \
  --machine-type "n1-standard-2" \
  --image-type "COS" \
  --disk-type "pd-standard" \
  --disk-size "100" \
  --metadata disable-legacy-endpoints=true \
  --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
  --num-nodes "2" \
  --enable-stackdriver-kubernetes \
  --default-max-pods-per-node "110" \
  --enable-autoscaling \
  --min-nodes "1" \
  --max-nodes "2" \
  --addons HorizontalPodAutoscaling,HttpLoadBalancing \
  --enable-autoupgrade \
  --enable-autorepair \
  --no-enable-master-authorized-networks \
  --enable-ip-alias \
  --enable-private-nodes \
  --no-enable-basic-auth \
  --no-issue-client-certificate \
  --master-ipv4-cidr "172.16.0.0/28" \
  --network "projects/poc-lanzarote/global/networks/custom-network1" \
  --subnetwork "projects/poc-lanzarote/regions/us-central1/subnetworks/subnet-us-central1-192"

gcloud container clusters get-credentials cluster-1

# gcloud compute instances list
# export NODE_NAME=gke-cluster-1-default-pool-c7fe4d7f-5fjz
# gcloud compute ssh $NODE_NAME --zone us-central1-c  --tunnel-through-iap
# ps aux | grep -i "\s/kube-dns"
# sudo nsenter --target PROCESS_ID --net /bin/bash
