resource "aws_cloudwatch_log_group" "log_group" {
  name = "lda-log-group"
}

resource "aws_cloudwatch_log_stream" "log_stream" {
  name           = "LDALogStream"
  log_group_name = "${aws_cloudwatch_log_group.log_group.name}"
}
