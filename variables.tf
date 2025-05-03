# variables.tf
variable "project_id" {
  type        = string
}

variable "service_email" {
  type        = string
}

variable "region" {
  description = "region"
  type        = string
  default     = "us-east1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Availability zone"
  type        = string
  default     = "us-east1-b"
}

variable "image" {
  description = "os image"
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2204-lts" # Ubuntu 22.04 LTS
}

variable "private_key_path" {
  description = "Path to the private key file to use for SSH connections between servers"
  type        = string
}