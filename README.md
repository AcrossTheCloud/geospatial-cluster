# geospatial-cluster
## Comments
Due to change of direction to on-prem non-Kubernetes solution, only the AWS solution is complete and tested.
## Overall requirements
1. Install [kubectl](https://kubernetes.io/docs/tasks/tools/)
2. Install [helm](https://helm.sh/docs/intro/install/#through-package-managers).
## AWS
### AWS-specific requirements
1. Install the [AWS CLI tool](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
2. Install [eksctl](https://eksctl.io/introduction/#installation)

In the aws/setup directory:
1. Edit the set_account_id.sh to fill in the (numeric, 12 digit) AWS account ID that you wish to create all resources in.
2. Run the setup.sh script. Note that the cluster creation step can take tens of minutes to run.
3. Check on $HOME/.kube/config - if this has `apiVersion: client.authentication.k8s.io/v1alpha1` then change it to `apiVersion: client.authentication.k8s.io/v1beta1

In the aws/storage directory:
1. Run the setup.sh script.
2. Make a note of the file_system_id and access_point_id
3. Edit pv.yaml so that the volumeHandle refers to those in the format `volumeHandle: file_system_id::access_point_id`, being careful not to change the indentation.
4. Create certificates in ACM in the desired region (the one the cluster is running in) with names = the desired DNS names.

### Single-node-specific requirements
Ensure the kubeconfig is copied to $HOME/.kube/config
## General
Set a password for the database in common/secret.yaml and then apply: `kubectl apply -f common/secret.yaml`.

Apply in order, from the relevant directory (e.g. for AWS, be in the aws directory): 
1. `kubectl apply -f storage/pv.yaml`
2. `kubectl apply -f storage/pvc.yaml`
3. `kubectl apply -f services/postgis.yaml`
4. Wait until the postgis pod is showing as STATUS=Running in `kubectl get pods` output.
5. `kubectl apply -f services/geonetwork.yaml`
6. `kubectl apply -f services/geoserver.yaml`
7. Wait for the geonetwork pod to be running and immediately log in and change the password for the admin user from admin to something more sensible.
8. Wait for the geoserver pod to be running and note its name (look for geoserver-randomstring1-randomstring2), and then run `kubectl exec --stdin --tty geoserver-randomstring1-randomstring2)-- /bin/bash` then at the prompt: `cat /opt/geoserver/data_dir/security/pass.txt` to get the initial geoserver login password. The default username is admin.

## Follow-up steps
### AWS-specific
In the AWS console navigate to EC2 > Load Balancers, and for each load balancer, click on tags to find out what it is for (look for the value default/ingress-geonetwork or default/ingress-geoserver by key ingress.k8s.aws/stack) and then create an A record aliased to that load balancer in Route53.

