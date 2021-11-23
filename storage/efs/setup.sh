#!/usr/bin/env bash
# from https://aws.amazon.com/premiumsupport/knowledge-center/eks-persistent-storage/

cluster_name="geospatial"
region="ap-southeast-2"
# set this: aws_account_id=""
export AWS_PAGER=""

curl -o iam-policy-example.json https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/v1.3.4/docs/iam-policy-example.json

aws iam create-policy \
    --policy-name AmazonEKS_EFS_CSI_Driver_Policy \
    --policy-document file://iam-policy-example.json

#eksctl utils associate-iam-oidc-provider --region=ap-southeast-2 --cluster $cluster_name --approve

aws eks describe-cluster --name $cluster_name --query "cluster.identity.oidc.issuer" --output text

kubectl apply -f efs-service-account.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/master/deploy/kubernetes/base/csidriver.yaml


vpc_id=$(aws eks describe-cluster \
    --name $cluster_name \
    --query "cluster.resourcesVpcConfig.vpcId" \
    --output text)

cidr_range=$(aws ec2 describe-vpcs \
    --vpc-ids $vpc_id \
    --query "Vpcs[].CidrBlock" \
    --output text)

security_group_id=$(aws ec2 create-security-group \
    --group-name GeospatialEFSSG \
    --description "My EFS security group" \
    --vpc-id $vpc_id \
    --output text)

aws ec2 authorize-security-group-ingress \
    --group-id $security_group_id \
    --protocol tcp \
    --port 2049 \
    --cidr $cidr_range

file_system_id=$(aws efs create-file-system \
    --region $region \
    --performance-mode generalPurpose \
    --query 'FileSystemId' \
    --output text)

# wait for it to be created
sleep 30

aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$vpc_id" \
    --query 'Subnets[*].{SubnetId: SubnetId,AvailabilityZone: AvailabilityZone,CidrBlock: CidrBlock}' > subnets.json

python3 process_subnets.py > subnets.txt

while read subnetID; do 
    echo "$subnetID"
    aws efs create-mount-target \
    --file-system-id $file_system_id \
    --subnet-id $subnetID \
    --security-groups $security_group_id
done < "subnets.txt"