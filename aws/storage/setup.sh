#!/usr/bin/env bash
# from https://aws.amazon.com/premiumsupport/knowledge-center/eks-persistent-storage/

cluster_name="geospatial"
region="ap-southeast-2"
export AWS_PAGER=""

curl -o iam-policy-example.json https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/v1.3.6/docs/iam-policy-example.json

aws iam create-policy \
    --policy-name AmazonEKS_EFS_CSI_Driver_Policy \
    --tags Key=project,Value=aurin \
    --policy-document file://iam-policy-example.json

eksctl create iamserviceaccount \
    --name efs-csi-controller-sa \
    --namespace kube-system \
    --cluster $cluster_name \
    --attach-policy-arn arn:aws:iam::$aws_account_id:policy/AmazonEKS_EFS_CSI_Driver_Policy \
    --approve \
    --override-existing-serviceaccounts \
    --tags Key=project,Value=aurin \
    --region $region

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
    --encrypted \
    --tags Key=project,Value=aurin \
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

access_point_id=$(aws efs create-access-point \
    --file-system-id $file_system_id \
    --posix-user Uid=501,Gid=501 \
    --root-directory 'Path=/geospatial,CreationInfo={OwnerUid=501,OwnerGid=501,Permissions=0750}' \
    --query 'AccessPointId' \
    --output text)
# make a note of this
echo file_system_id $file_system_id
echo access_point_id $access_point_id
