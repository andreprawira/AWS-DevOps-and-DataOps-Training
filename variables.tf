variable "website_bucket_name" {
    default = "digbick-ui"
}
locals {
  common_tags = {
    Project   = "LDA"
  }
}