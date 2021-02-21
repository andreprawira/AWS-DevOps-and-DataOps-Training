resource "aws_s3_bucket" "lda-athena" {
  bucket = "lda-athena"
  tags = "${merge(
    local.common_tags
  )}"
}

