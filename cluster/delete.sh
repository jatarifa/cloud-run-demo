#!/bin/bash

gcloud container clusters delete poc-cluster --zone=us-central1-b --quiet
gcloud pubsub topics delete testing