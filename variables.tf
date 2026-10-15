# ------------------------------------------------------------------------------
# General
# ------------------------------------------------------------------------------

variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster. Also used as a prefix for most resources."
  type        = string
  default     = "devops-demo"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,38}[a-z0-9]$", var.cluster_name))
    error_message = "cluster_name must be 2-40 chars, lowercase alphanumeric or hyphens, and start/end with an alphanumeric character."
  }
}

variable "environment" {
  description = "Environment label applied to resource tags (e.g. dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Extra tags merged into every tagged resource."
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# Networking
# ------------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Public subnets take the first N /24s, private subnets the next N."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "az_count" {
  description = "Number of availability zones to span (and number of public/private subnet pairs)."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 4
    error_message = "az_count must be between 1 and 4."
  }
}

variable "single_nat_gateway" {
  description = "Set true to provision a single NAT gateway (cheaper, but a single point of failure and cross-AZ data charges). False = one NAT per AZ."
  type        = bool
  default     = false
}

# ------------------------------------------------------------------------------
# EKS cluster
# ------------------------------------------------------------------------------

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.36"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint. Restrict this to office/VPN ranges in real deployments."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "admin_role_arn" {
  description = "Optional IAM role/user ARN to grant cluster-admin via an EKS access entry. Leave empty to skip."
  type        = string
  default     = ""
}

# ------------------------------------------------------------------------------
# Managed node group
# ------------------------------------------------------------------------------

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_ami_type" {
  description = "AMI type for worker nodes (e.g. AL2023_x86_64_STANDARD, AL2_x86_64)."
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 4
}

variable "node_disk_size" {
  description = "Disk size (GiB) for worker node root volumes."
  type        = number
  default     = 30
}
