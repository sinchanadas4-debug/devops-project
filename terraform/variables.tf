variable "aws_region" {
  default = "ap-south-1"
}

variable "project_name" {
  default = "devops-project"
}

variable "instance_type" {
  default = "t3.small"
}

variable "my_ip" {
  description = "Your home public IP, allowed to SSH"
  type        = string
}

variable "key_name" {
  default = "devops-project-key"
}

variable "services" {
  type    = list(string)
  default = ["user-service", "product-service", "order-service"]
}