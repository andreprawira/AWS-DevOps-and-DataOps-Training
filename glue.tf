resource "aws_glue_job" "raw-to-conform" {
  name     = "raw-to-conform-job"
  role_arn = "${aws_iam_role.raw-to-conform.arn}"

  command {
    script_location = "s3://${aws_s3_bucket.glue-bucket.bucket}/raw-to-conform.py"
  }
}

resource "aws_iam_role" "raw-to-conform" {
  name               = "AWSGlueServiceRoleDefault2"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = "${aws_iam_role.raw-to-conform.id}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "glue_service2" {
  role       = "${aws_iam_role.raw-to-conform.id}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_glue_crawler" "raw-to-conform" {
  database_name = "${aws_glue_catalog_database.raw.name}"
  name          = "raw-to-conform"
  role          = "${aws_iam_role.raw-to-conform.arn}"

  s3_target {
    path = "s3://${aws_s3_bucket.raw-bucket.bucket}"
  }

  tags = "${merge(
    local.common_tags
  )}"
}

resource "aws_glue_crawler" "conform" {
  database_name = "${aws_glue_catalog_database.conform.name}"
  name          = "conform"
  role          = "${aws_iam_role.raw-to-conform.arn}"

  s3_target {
    path = "s3://${aws_s3_bucket.conform-bucket.bucket}"
  }

  tags = "${merge(
    local.common_tags
  )}"
}


resource "aws_glue_catalog_database" "raw" {
  name = "raw"
}

resource "aws_glue_catalog_database" "conform" {
  name = "conform"
}