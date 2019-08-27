variable "aws_region" {}
variable "aws_profile" {}
data "aws_availability_zones" "available" {}
variable "vpc_cidr" {}
variable "vpc_sn1_cidr" {}
variable "vpc_sn2_cidr" {}
variable "vpc_sn3_cidr" {}
variable "vpc_sn4_cidr" {}
variable "cidrs" {
  type = "map"
}
variable "localip" {}
variable "bucket_name" {}
variable "db_instance_class" {}
variable "dbname" {}
variable "dbuser" {}
variable "dbpassword" {}
variable "dev_instance_type" {}
variable "dev_ami" {}
variable "key_name" {}
variable "public_key_path" {}
