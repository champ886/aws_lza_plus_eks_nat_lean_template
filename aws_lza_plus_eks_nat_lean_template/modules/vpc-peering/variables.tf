variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "environment" {
  type = string
}

variable "peering_name" {
  type = string
}

variable "requester_vpc_id" {
  type = string
}

variable "requester_vpc_cidr" {
  type = string
}

variable "requester_route_table_az_a_id" {
  type = string
}

variable "requester_route_table_az_b_id" {
  type = string
}

variable "accepter_account_id" {
  type = string
}

variable "accepter_vpc_id" {
  type = string
}

variable "accepter_vpc_cidr" {
  type = string
}

variable "accepter_route_table_az_a_id" {
  type = string
}

variable "accepter_route_table_az_b_id" {
  type = string
}

variable "route_internet_via_accepter" {
  description = "Route 0.0.0.0/0 from requester through accepter NAT GW"
  type        = bool
  default     = false
}

# Add this to modules/vpc-peering/variables.tf

variable "accepter_public_route_table_id" {
  description = "Accepter (security) public route table ID - needed for NAT gateway return routes"
  type        = string
  default     = ""  # Optional - only required when route_internet_via_accepter = true
}
