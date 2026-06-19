variable "environment"  { type = string }
variable "cluster_name" { type = string }
variable "azs" {
  type = list(string)
  validation {
    condition     = length(var.azs) == 3
    error_message = "Exactly 3 AZs required."
  }
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR."
  }
}
variable "public_subnet_cidrs" {
  type = list(string)
  validation {
    condition     = length(var.public_subnet_cidrs) == 3
    error_message = "Exactly 3 public CIDRs required."
  }
}
variable "private_subnet_cidrs" {
  type = list(string)
  validation {
    condition     = length(var.private_subnet_cidrs) == 3
    error_message = "Exactly 3 private CIDRs required."
  }
}
