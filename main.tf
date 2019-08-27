provider "aws" {
  region  = "${var.aws_region}"
#  profile = "${var.aws_profile}"
}

##-----Instance profile and S3 role for EC2 instances to access S3
resource "aws_iam_instance_profile" "s3_access_profile" {
    name = "s3_access"
    role = "${aws_iam_role.s3_access_role.name}"
}
resource "aws_iam_role_policy" "s3_access_policy" {
    name = "s3_access_policy"
    role = "${aws_iam_role.s3_access_role.id}"
    policy = <<EOF
{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "s3:ListBucket",
            "s3:GetObject"
          ],
          "Resource": [
            "${aws_s3_bucket.wp_cloudtrail.arn}"
          ]
        }
      ]
}
EOF
}

resource "aws_iam_role" "s3_access_role" {
    name = "s3accessrole"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
#-------------VPC----------------
resource "aws_vpc" "wp_vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    name = "wp_vpc"
  }
}
#---------Internet Gateway -------
resource "aws_internet_gateway" "wp_igw" {
  vpc_id = "${aws_vpc.wp_vpc.id}"
  tags = {
    Name = "wp_igw"
  }
}
#-----Public Route Table----------
resource "aws_route_table" "wp_public_rt" {
  vpc_id = "${aws_vpc.wp_vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.wp_igw.id}"
  }
  tags = {
    Name = "wp_public"
  }
}
#------Default Route table - Private route-----
resource "aws_default_route_table" "wp_private_rt" {
  default_route_table_id = "${aws_vpc.wp_vpc.default_route_table_id}"
  tags = {
    Name = "wp_private"
  }
}
resource "aws_subnet" "wp_public1_sn" {
  vpc_id     = "${aws_vpc.wp_vpc.id}"
  cidr_block = "${var.cidrs["public1"]}"
  #route_table_id = "{aws_vpc.wp_vpc.wp_public_rt}"
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"
  map_public_ip_on_launch = true
  tags = {
    Name = "wp_public1"
  }
}
resource "aws_subnet" "wp_public2_sn" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "${var.cidrs["public2"]}"
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"
  map_public_ip_on_launch = true
  tags = {
    Name = "wp_public2"
  }
}
resource "aws_subnet" "wp_private1_sn" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "${var.cidrs["private1"]}"
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"
  map_public_ip_on_launch = false
  tags = {
    Name = "wp_private1"
  }
}

resource "aws_subnet" "wp_private2_sn" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "${var.cidrs["private2"]}"
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"
  map_public_ip_on_launch = false
  tags = {
    Name = "wp_private2"
  }
}

##SUBNET and ROUTE TABLE ASSOCIATION
resource "aws_route_table_association" "wp_public1_assoc" {
  subnet_id      = "${aws_subnet.wp_public1_sn.id}"
  route_table_id = "${aws_route_table.wp_public_rt.id}"
}
resource "aws_route_table_association" "wp_public2_assoc" {
  subnet_id      = "${aws_subnet.wp_public2_sn.id}"
  route_table_id = "${aws_route_table.wp_public_rt.id}"
}
resource "aws_route_table_association" "wp_private_assoc" {
  subnet_id      = "${aws_subnet.wp_private1_sn.id}"
  route_table_id = "${aws_default_route_table.wp_private_rt.id}"
}
resource "aws_route_table_association" "wp_private2_assoc" {
  subnet_id      = "${aws_subnet.wp_private2_sn.id}"
  route_table_id = "${aws_default_route_table.wp_private_rt.id}"
}

##CREATING SECURITY GROUPS
#PUBLIC SECURITY GROUP
resource "aws_security_group" "wp_public1_sg" {
  name        = "wp_publc1_sg"
  description = "Used for accessing public instances"
  vpc_id      = "${aws_vpc.wp_vpc.id}"
  #SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["${var.localip}"]
  }
  #HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["${var.localip}"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
##PRIVATE SECURITY GROUP
resource "aws_security_group" "wp_private1_sg" {
  name        = "wp_private1_sg"
  description = "Used for accessing public instances"
  vpc_id      = "${aws_vpc.wp_vpc.id}"
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.vpc_cidr}"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
##PRIVATE SECURITY GROUP FOR RDS------------
resource "aws_security_group" "wp_rds_sg" {
  name        = "wp_rds_sg"
  description = "Used for accessing RDS MYSQL"
  vpc_id      = "${aws_vpc.wp_vpc.id}"
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "TCP"
    cidr_blocks = ["${var.vpc_cidr}"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
##S3 ACCESS VIA VPC END POINT
resource "aws_vpc_endpoint" "wp_private_s3_endpoint" {
  vpc_id       = "${aws_vpc.wp_vpc.id}"
  service_name = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = ["${aws_vpc.wp_vpc.main_route_table_id}",
  "${aws_route_table.wp_public_rt.id}"]
  ###END POINT ACCESS POLICY
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.wp_cloudtrail.arn}"
      ],
      "Principal": "*"
    }
  ]
}
POLICY
}

##ADD S3 CLOUDTRAIL BUCKET

resource "aws_s3_bucket" "wp_cloudtrail" {
  bucket        = "${var.bucket_name}"
  acl           = "private"
  force_destroy = true
  tags = {
    Name = "Cloudtrail bucket"
  }
}

##creating DB subnet group
resource "aws_db_subnet_group" "wp_db_sng" {
  name       = "wp_db_sng"
  subnet_ids = ["${aws_subnet.wp_private1_sn.id}", "${aws_subnet.wp_private2_sn.id}"]

  tags = {
    Name = "wp_db_sn_grp"
  }
}
##CREATING THE RDS INSTANCE

resource "aws_db_instance" "wp_db" {
  allocated_storage = 10
  engine = "mysql"
  engine_version = "5.7.21"
  instance_class = "${var.db_instance_class}"
  name = "${var.dbname}"
  username = "${var.dbuser}"
  password = "${var.dbpassword}"
  db_subnet_group_name = "${aws_db_subnet_group.wp_db_sng.id}"
  vpc_security_group_ids = ["${aws_security_group.wp_rds_sg.id}"]
  skip_final_snapshot = true
}

##CREATE WP_DEV INSTANCE ND KEY PAIR

#KEY PAIR
resource "aws_key_pair" "wp_auth" {
  key_name = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

#DEV SERVER
resource "aws_instance" "wp_dev" {
    instance_type = "${var.dev_instance_type}"
    ami = "${var.dev_ami}"
    tags = {
      Name = "wp_dev"
    }
    key_name = "${aws_key_pair.wp_auth.id}"
    vpc_security_group_ids = ["${aws_security_group.wp_public1_sg.id}"]
    iam_instance_profile = "${aws_iam_instance_profile.s3_access_profile.id}"
    subnet_id = "${aws_subnet.wp_public1_sn.id}"
    ##CREATE AWS HOST file for ANSIBLE
    provisioner "local-exec" {
      command = <<EOD
      cat <<EOF > aws_hosts
      [dev]
      ${aws_instance.wp_dev.public_ip}
      [dev:vars]
      s3cloudtrail=${aws_s3_bucket.wp_cloudtrail.bucket}
      EOF
EOD
      }
#    provisioner "local-exec" {
#      command = "aws ec2 wait instance-status-ok --instance-ids ${aws_instance.wp_dev} && ansible-playbook -i aws_hosts pyspark.yml"
#    }
}

##AWS VPC Flow Log to S3 bucket vpcaccesscloudtrail
#resource "aws_flow_log" "wp_vpc_flow" {
#    log_destination = "${aws_s3_bucket.wp_cloudtrail.arn}"
#    log_destination_type = "s3"
#    traffic_type = "ALL"
#    vpc_id = "${aws_vpc.wp_vpc.id}"
#}

resource "aws_flow_log" "wp_flow_log" {
    iam_role_arn = "${aws_iam_role.wp_vpc_cloudwatch_role.arn}"
    log_destination = "${aws_cloudwatch_log_group.wp_cloudwatch_log.arn}"
    traffic_type = "ACCEPT"
    vpc_id = "${aws_vpc.wp_vpc.id}"
}

resource "aws_cloudwatch_log_group" "wp_cloudwatch_log" {
  name = "wp_cloudwatch_log"
}

resource "aws_cloudwatch_log_stream" "wp_cloudwatch_stream" {
    name = "wp_cloudwatch_stream"
    log_group_name = "${aws_cloudwatch_log_group.wp_cloudwatch_log.name}"
}

resource "aws_iam_role" "wp_vpc_cloudwatch_role" {
    name = "wp_vpc_cloudwatch_role"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
      "Service": "vpc-flow-logs.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "wp_cloudwatch_policy" {
    name = "wp_cloudwatch_policy"
    role = "${aws_iam_role.wp_vpc_cloudwatch_role.id}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

##Cloudwatch metric to find not expected source IPs
resource "aws_cloudwatch_log_metric_filter" "wp_cloudwatch_filter" {
    name = "wp_cloudwatch_vpc_filter"
    pattern = "[version, accountid, interfaceid, srcaddr!=75.188.37.211, dstaddr, srcport, distport, protocol, packets, bytes, start, end, action, logstatus]"
    log_group_name = "${aws_cloudwatch_log_group.wp_cloudwatch_log.name}"
    metric_transformation {
      name = "BadIpCount"
      namespace = "GvpcFlowLogTrack"
      value = "1"
    }
}

##Cloudwatch subscription filter to send events in log group to Lamda function
resource "aws_cloudwatch_log_subscription_filter" "wp_flow_log_destination" {
    name = "wp_flow_log_lambda_stream_subscription"
    log_group_name = "${aws_cloudwatch_log_group.wp_cloudwatch_log.name}"
    destination_arn = "${aws_lambda_function.wp_flow_log_exec_lambda.arn}"
    filter_pattern = "[version, accountid, interfaceid, srcaddr!=75.188.37.211, dstaddr, srcport, distport, protocol, packets, bytes, start, end, action, logstatus]"

}
###Allow stream to Lambda
resource "aws_lambda_permission" "wp_flow_log_to_lambda_perm" {
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.wp_flow_log_exec_lambda.function_name}"
    principal = "logs.${var.aws_region}.amazonaws.com"
    statement_id = "AllowExecutionFromCloudWatch"
    source_arn = "${aws_cloudwatch_log_group.wp_cloudwatch_log.arn}"
}

##Kineses firehose stream

resource "aws_kinesis_firehose_delivery_stream" "wp_flow_log_firehose" {
    name = "wp_flow_log_firehose"
    destination = "s3"
    s3_configuration {
      bucket_arn = "${aws_s3_bucket.wp_cloudtrail.arn}"
      role_arn = "${aws_iam_role.wp_firehose_role.arn}"
      buffer_size = 10
      buffer_interval = 400
      compression_format = "GZIP"
    }
}

resource "aws_iam_role" "wp_firehose_role" {
    name = "wp_firehose_role"
    assume_role_policy = "${data.aws_iam_policy_document.wp_iam_firehose_policy_assume_doc.json}"
}

resource "aws_iam_role_policy" "wp_iam_firehose_policy" {
    name = "wp_iam_firehose_policy"
    role = "${aws_iam_role.wp_firehose_role.id}"
    policy = "${data.aws_iam_policy_document.wp_iam_policy_firehose_doc.json}"
}

data "aws_iam_policy_document" "wp_iam_firehose_policy_assume_doc" {
  statement {
    effect = "Allow"
    principals  {
      type = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "wp_iam_policy_firehose_doc" {
  statement {
    effect = "Allow"
    resources = ["${aws_s3_bucket.wp_cloudtrail.arn}"]
    actions = [
      "s3:ListBucket"
    ]
  }
  statement {
    effect = "Allow"
    resources = ["${aws_s3_bucket.wp_cloudtrail.arn}/*"]
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject"
    ]
  }
}

##Lambda Flow logs to kinesis
resource "aws_lambda_function" "wp_flow_log_exec_lambda" {
    filename = "lambda.zip"
    source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}"
    function_name = "VPCFlowLogsToFirehose"
    handler = "lambdacode.lamda_handler"
    role = "${aws_iam_role.wp_iam_lambda_kinesis_exec_role.arn}"
    runtime = "python2.7"
    timeout = 300
    memory_size = 512
    environment {
      variables={
        DELIVERY_STREAM_NAME = "${aws_kinesis_firehose_delivery_stream.wp_flow_log_firehose.name}"
      }
    }
}
##IAM role for Lambda to Kinesis Exec
resource "aws_iam_role" "wp_iam_lambda_kinesis_exec_role" {
    name = "wp_lambda_kinesis_exec_role"
    assume_role_policy = "${data.aws_iam_policy_document.wp_iam_lambda_policy_assume_doc.json}"
}

### IAM Policy Lambda Kinesis Exec
resource "aws_iam_role_policy" "wp_iam_lambda_kinesis_exec_policy" {
    name = "wp_iam_lambda_kinesis_exec_policy"
    role = "${aws_iam_role.wp_iam_lambda_kinesis_exec_role.arn}"
    policy = "${data.aws_iam_policy_document.wp_iam_policy_lambda_doc.json}"
}

data "archive_file" "lambda_zip" {
  type = "zip"
  source_dir = "${path.module}/lambda"
  output_path = "lambda.zip"
}
data "aws_iam_policy_document" "wp_iam_lambda_policy_assume_doc" {
  statement {
    effect = "Allow"
    principals  {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "wp_iam_policy_lambda_doc" {
  statement {
    effect = "Allow"
    resources = ["*"]
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
  }
  statement {
    effect = "Allow"
    resources = ["${aws_kinesis_firehose_delivery_stream.wp_flow_log_firehose.arn}"]
    actions = [
      "firehose:PutRecordBatch"
    ]
  }
}
