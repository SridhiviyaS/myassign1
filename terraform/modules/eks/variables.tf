variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "public_subnets" {
  type = list(string)
}

variable "jenkins_role_arn" {
  description = "ARN of the Jenkins IAM role to grant EKS cluster access"
  type        = string
}