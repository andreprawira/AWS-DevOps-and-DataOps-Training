provider "aws" {
  region = "us-east-2"
}
## Specifies the S3 Bucket and DynamoDB table used for the durable backend and state locking

terraform {
    backend "s3" {
      encrypt = true
      bucket = "digbick"
      dynamodb_table = "terraform-state-lock-dynamo"
      key = "terraform.tfstate"
      region = "us-east-2"
  }
}