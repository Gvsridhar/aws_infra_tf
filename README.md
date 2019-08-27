AWS VPC Flow log analysis
This is a Terraform code to analyse the VPC flow logs using AWS services such as Cloudwatch logs, Kineses firehose, Lambda, S3 and Athena.

The code performs below steps
1. Create VPC, subnets, IGW, Routing tables, Security groups, MySQL RDS instance, EC2 instance.
2. IAM roles and policies
3. S3 bucket to store VPC flow logs
4. Cloudwatch log group.
5. Kineses stream
6. Lambda function to ingest log to Kinesis firehose.
