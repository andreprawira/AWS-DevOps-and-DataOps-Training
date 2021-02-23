resource "aws_kinesis_stream" "stream" {
  name        = "lda-stream1"
  shard_count = 2
  tags = "${merge(
    local.common_tags,
    local.kinesis_module_tags
  )}"
}



resource "aws_iam_role" "firehose_role" {
  name               = "lda_firehose_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "firehose_role_policy" {
  name   = "lda_firehose_role_policy"
  role   = "${aws_iam_role.firehose_role.id}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "glue:GetTable",
                "glue:GetTableVersion",
                "glue:GetTableVersions"
            ],
            "Resource": "*"
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "s3:AbortMultipartUpload",
                "s3:GetBucketLocation",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:ListBucketMultipartUploads",
                "s3:PutObject"
            ],
            "Resource": [
                "${aws_s3_bucket.raw-bucket.arn}",
                "${aws_s3_bucket.raw-bucket.arn}/*"
            ]
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "logs:PutLogEvents"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "kinesis:DescribeStream",
                "kinesis:GetShardIterator",
                "kinesis:GetRecords"
            ],
            "Resource": "${aws_kinesis_stream.stream.arn}"
        }]}
EOF
}

resource "aws_kinesis_firehose_delivery_stream" "firehose_stream" {
  #count = "${var.firehose_count}"
  name        = "lda-firehose"
  destination = "s3"
  s3_configuration {
    role_arn        = "${aws_iam_role.firehose_role.arn}"
    bucket_arn      = "${aws_s3_bucket.raw-bucket.arn}"
    buffer_size     = 5
    buffer_interval = 60
    cloudwatch_logging_options {
      enabled         = "true"
      log_group_name  = "${aws_cloudwatch_log_group.log_group.name}"
      log_stream_name = "${aws_cloudwatch_log_stream.log_stream.name}"
    }
  }
  kinesis_source_configuration {
    kinesis_stream_arn = "${aws_kinesis_stream.stream.arn}"
    role_arn           = "${aws_iam_role.firehose_role.arn}"
  }
  tags = "${merge(
    local.common_tags,
    local.kinesis_module_tags
  )}"
}

locals {
  kinesis_module_tags = {
    module = "Kinesis"
  }
}

