data "archive_file" "crawler-lambda_zip_dir" {
  type        = "zip"
  output_path = "/tmp/crawler-lambda_zip_dir.zip"
  source_dir  = "crawler-lambda"
}

resource "aws_lambda_function" "jobAutomation" {
  filename         = "${data.archive_file.crawler-lambda_zip_dir.output_path}"
  source_code_hash = "${data.archive_file.crawler-lambda_zip_dir.output_base64sha256}"
  function_name = "jobAutomation"
  runtime = "python3.7"
  handler = "jobAutomation.lambda_handler"
  role = "${aws_iam_role.lambda_role.arn}"
  tags = "${merge(
    local.common_tags
  )}"

}

resource "aws_lambda_function" "conformAutomation" {
  filename         = "${data.archive_file.crawler-lambda_zip_dir.output_path}"
  source_code_hash = "${data.archive_file.crawler-lambda_zip_dir.output_base64sha256}"
  function_name = "conformAutomation"
  runtime = "python3.7"
  handler = "conformAutomation.lambda_handler"
  role = "${aws_iam_role.lambda_role.arn}"
  tags = "${merge(
    local.common_tags
  )}"

}

resource "aws_lambda_function" "crawlerAutomation" {
  filename         = "${data.archive_file.crawler-lambda_zip_dir.output_path}"
  source_code_hash = "${data.archive_file.crawler-lambda_zip_dir.output_base64sha256}"
  function_name = "crawlerAutomation"
  runtime = "python3.7"
  handler = "crawlerAutomation.lambda_handler"
  role = "${aws_iam_role.lambda_role.arn}"
  tags = "${merge(
    local.common_tags
  )}"

}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com"
        ]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_role_policy" {
  name   = "lambda_role_policy"
  role   = "${aws_iam_role.lambda_role.id}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:*"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Action": [
                "dynamodb:BatchGetItem",
                "dynamodb:BatchWriteItem",
                "dynamodb:CreateTable",
                "dynamodb:DeleteBackup",
                "dynamodb:DeleteItem",
                "dynamodb:DescribeGlobalTable",
                "dynamodb:DescribeGlobalTableSettings",
                "dynamodb:DescribeLimits",
                "dynamodb:GetItem",
                "dynamodb:GetRecords",
                "dynamodb:PutItem",
                "dynamodb:Query",
                "dynamodb:Scan",
                "dynamodb:UpdateItem",
                "dynamodb:UpdateTable"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "codebuild:BatchGetBuilds",
                "codebuild:StartBuild"
            ],
            "Resource": "*"
        },
        {
            "Action": [
                "s3:CreateBucket",
                "s3:DeleteBucket",
                "s3:Get*",
                "s3:ListAllMyBuckets",
                "s3:List*",
                "s3:Put*"
            ],
            "Effect": "Allow",
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_glue_service" {
  role       = "${aws_iam_role.lambda_role.id}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "s3_service" {
  role       = "${aws_iam_role.lambda_role.id}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "cognito_service" {
  role       = "${aws_iam_role.lambda_role.id}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonCognitoPowerUser"
}

resource "aws_iam_role_policy_attachment" "glue_access" {
  role       = "${aws_iam_role.lambda_role.id}"
  policy_arn = "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess"
}

resource "aws_cloudwatch_event_rule" "crawlerTrigger" {
  name        = "crawlerTrigger"
  description = "Triggers the 'raw-to-conform-job' when the 'raw-to-conform' crawler is succeded."

  event_pattern = <<PATTERN
{
  "detail-type": [
    "Glue Crawler State Change"
  ],
  "source": [
    "aws.glue"
  ],
  "detail": {
    "crawlerName": [
      "raw-to-conform"
    ],
    "state": [
      "Succeeded"
    ]
  }
}
PATTERN
}


resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.crawlerAutomation.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.crawlerTrigger.arn}"
}

resource "aws_cloudwatch_event_target" "crawlerAutomation" {
  rule      = "${aws_cloudwatch_event_rule.crawlerTrigger.name}"
  target_id = "crawlerAutomation"
  arn       = "${aws_lambda_function.crawlerAutomation.arn}"
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.jobAutomation.arn}"
  principal     = "s3.amazonaws.com"
  source_arn    = "${aws_s3_bucket.raw-bucket.arn}"
}


resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = "${aws_s3_bucket.raw-bucket.id}"
  
  lambda_function {
    lambda_function_arn = "${aws_lambda_function.jobAutomation.arn}"
    events              = ["s3:ObjectCreated:*"]
  }
}

resource "aws_lambda_permission" "allow_conform_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.conformAutomation.arn}"
  principal     = "s3.amazonaws.com"
  source_arn    = "${aws_s3_bucket.conform-bucket.arn}"
}


resource "aws_s3_bucket_notification" "conform_bucket_notification" {
  bucket = "${aws_s3_bucket.conform-bucket.id}"
  
  lambda_function {
    lambda_function_arn = "${aws_lambda_function.conformAutomation.arn}"
    events              = ["s3:ObjectCreated:*"]
  }
}