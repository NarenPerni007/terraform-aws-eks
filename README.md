# terraform-aws-eks

Production-style Terraform for an **AWS VPC + Amazon EKS** cluster, written with raw `aws_*` resources (no wrapper modules) so every piece of the networking, IAM, and cluster wiring is explicit and reviewable.

## What it provisions

- **VPC** (`10.0.0.0/16` by default) with DNS support enabled
- **Public and private subnets** across N availability zones (3 by default)
- **Internet gateway**, **NAT gateway(s)**, and public/private **route tables**
- **EKS cluster** with the Kubernetes API reachable privately and publicly
- **Managed node group** of EC2 workers in the private subnets (no public IPs)
- **IAM roles** for the cluster and the nodes with least-privilege AWS managed policies
- **Security groups** for the control plane and the nodes
- **Optional EKS access entry** granting cluster-admin to an IAM principal
- Kubernetes subnet discovery tags (`kubernetes.io/role/elb`, `kubernetes.io/role/internal-elb`) so the AWS Load Balancer Controller works out of the box

## Architecture

```
                        ┌──────────────────────────────────────────────────┐
                        │                    AWS Region                     │
                        │                                                  │
                        │   ┌──────────────┐                                │
                        │   │ Internet GW  │                                │
                        │   └──────┬───────┘                                │
                        │          │                                        │
                        │  ┌───────┴───────────────────────────────────┐   │
                        │  │              Public route table            │   │
                        │  │            0.0.0.0/0 → IGW                │   │
                        │  └───────┬───────────────┬───────────────────┘   │
                        │          │               │                       │
                        │   ┌──────┴──────┐ ┌──────┴──────┐  ┌───────────┐  │
                        │   │ Public      │ │ Public      │  │ Public    │  │
                        │   │ subnet AZ-a │ │ subnet AZ-b │  │ subnet…   │  │
                        │   │  ┌───────┐  │ │  ┌───────┐  │  │           │  │
                        │   │  │ NAT GW │  │ │  │ NAT GW │  │  │           │  │
                        │   │  └───┬───┘  │ │  └───┬───┘  │  │           │  │
                        │   └──────┼──────┘ └──────┼──────┘  └───────────┘  │
                        │          │               │                       │
                        │  ┌───────┴───────┐ ┌─────┴─────────┐ ┌─────────┐ │
                        │  │ Private RT    │ │ Private RT    │ │ Private │ │
                        │  │ 0.0.0.0/0 →   │ │ 0.0.0.0/0 →   │ │ RT …    │ │
                        │  │ NAT GW (AZ-a) │ │ NAT GW (AZ-b) │ │         │ │
                        │  └───────┬───────┘ └─────┬─────────┘ └────┬────┘ │
                        │          │               │                │      │
                        │   ┌──────┴──────┐ ┌──────┴──────┐  ┌──────┴───┐  │
                        │   │ Private     │ │ Private     │  │ Private  │  │
                        │   │ subnet AZ-a │ │ subnet AZ-b │  │ subnet … │  │
                        │   │ ┌─────────┐ │ │ ┌─────────┐ │  │          │  │
                        │   │ │EKS nodes│ │ │ │EKS nodes│ │  │          │  │
                        │   │ │(no pub  │ │ │ │(no pub  │ │  │          │  │
                        │   │ │ IPs)    │ │ │ │ IPs)    │ │  │          │  │
                        │   │ └─────────┘ │ │ └─────────┘ │  │          │  │
                        │   └─────────────┘ └─────────────┘  └──────────┘  │
                        │                                                  │
                        │   EKS control plane (AWS-managed) ◄── 443 ──►    │
                        │   nodes (private API endpoint + public endpoint) │
                        └──────────────────────────────────────────────────┘
```

Traffic flow: nodes live in private subnets with no public IPs. Inbound to the Kubernetes API goes through the EKS endpoint; outbound (image pulls, patching, external APIs) leaves through the AZ-local NAT gateway.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [AWS CLI](https://aws.amazon.com/cli/) v2 with credentials configured (`aws configure` or env vars)
- An AWS account with permissions to create VPC, EC2, IAM, and EKS resources
- `kubectl` (for verifying the cluster afterwards)

## Quickstart

```bash
# 1. Clone and enter the repo
git clone https://github.com/<you>/terraform-aws-eks.git
cd terraform-aws-eks

# 2. (Optional) tune the inputs, e.g.:
#    terraform apply -var="cluster_name=my-cluster" -var="region=us-west-2" \
#                    -var="admin_role_arn=arn:aws:iam::123456789012:role/Admin"

# 3. Plan and apply (takes ~15-20 minutes — EKS control plane is the slow part)
terraform init
terraform plan
terraform apply

# 4. Point kubectl at the new cluster (command also printed as an output)
aws eks update-kubeconfig --region us-east-1 --name devops-demo
kubectl get nodes
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `region` | AWS region to deploy into | `string` | `"us-east-1"` |
| `cluster_name` | EKS cluster name; also prefixes most resources | `string` | `"devops-demo"` |
| `environment` | Environment label applied to resource tags | `string` | `"dev"` |
| `tags` | Extra tags merged into every tagged resource | `map(string)` | `{}` |
| `vpc_cidr` | CIDR block for the VPC | `string` | `"10.0.0.0/16"` |
| `az_count` | Number of AZs (and public/private subnet pairs) | `number` | `3` |
| `single_nat_gateway` | `true` = one NAT GW (cheaper, SPOF); `false` = one per AZ | `bool` | `false` |
| `cluster_version` | Kubernetes version for the EKS control plane | `string` | `"1.29"` |
| `cluster_endpoint_public_access_cidrs` | CIDRs allowed to reach the public API endpoint | `list(string)` | `["0.0.0.0/0"]` |
| `admin_role_arn` | IAM principal ARN to grant cluster-admin (empty = skip) | `string` | `""` |
| `node_instance_types` | EC2 instance types for the node group | `list(string)` | `["t3.medium"]` |
| `node_ami_type` | AMI type for worker nodes | `string` | `"AL2023_x86_64_STANDARD"` |
| `node_desired_size` | Desired worker node count | `number` | `2` |
| `node_min_size` | Minimum worker node count | `number` | `1` |
| `node_max_size` | Maximum worker node count | `number` | `4` |
| `node_disk_size` | Root volume size (GiB) for worker nodes | `number` | `30` |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | ID of the provisioned VPC |
| `public_subnet_ids` | IDs of the public subnets (one per AZ) |
| `private_subnet_ids` | IDs of the private subnets hosting the EKS nodes |
| `nat_gateway_ids` | IDs of the NAT gateways |
| `cluster_name` | Name of the EKS cluster |
| `cluster_endpoint` | API server endpoint of the EKS cluster |
| `cluster_security_group_id` | Security group attached to the control-plane ENIs |
| `node_group_name` | Name of the managed node group |
| `kubeconfig_command` | Ready-to-run `aws eks update-kubeconfig` command |

## Cleanup

```bash
terraform destroy
```

This removes the cluster, node group, NAT gateways (and their Elastic IPs), and the VPC. Note: EKS-managed load balancers created by in-cluster Services are **not** managed by this Terraform — delete those Kubernetes resources first or they will leave orphaned AWS resources behind.

## Design decisions

- **Private worker nodes.** Nodes get no public IPs; all egress goes through NAT. This shrinks the attack surface and matches how most regulated production environments run EKS.
- **One NAT gateway per AZ (default).** Keeps each AZ's egress independent — no cross-AZ data charges and no single point of failure. The trade-off is cost (~$33/mo per NAT gateway plus data processing). Set `single_nat_gateway = true` for dev/test to collapse to one NAT.
- **Managed node groups over self-managed.** AWS handles AMI patching, rolling updates, and graceful draining. Less undifferentiated heavy lifting than running your own Auto Scaling groups.
- **`API_AND_CONFIG_MAP` authentication mode.** Uses the modern EKS Access Entry API for RBAC while still honoring the legacy `aws-auth` ConfigMap, so existing tooling keeps working. The optional `admin_role_arn` variable wires up a cluster-admin access entry without touching YAML.
- **API + audit control-plane logging** is enabled by default for a usable audit trail.
- **Recommended next step: IRSA.** For production, add an `aws_iam_openid_connect_provider` for the cluster's OIDC issuer and use IAM Roles for Service Accounts so pods get scoped AWS permissions instead of sharing the node role. Deliberately left out here to keep the repo dependency-free (AWS provider only).
