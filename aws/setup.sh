#!/usr/bin/env bash

# from https://docs.aws.amazon.com/eks/latest/userguide/getting-started-eksctl.html

cluster_name="geospatial"
namespace="geospatial"
region="ap-southeast-2"
version="1.21"
export AWS_PAGER=""

eksctl create cluster \
  --name $cluster_name \
  --region $region \
  --version $version \
  --fargate

eksctl create fargateprofile --namespace $namespace --name $namespace --cluster $cluster_name

