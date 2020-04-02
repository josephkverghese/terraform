resource "aws_kms_key" "s3key" {
  description = "This key is used to encrypt s3 license bucket"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket" "s3_bucket" {
  bucket = var.s3_bucket_name
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.s3key.arn
        sse_algorithm = "aws:kms"
      }
    }
    tags = {
      Name = var.s3_bucket_name
    }
  }
}

resource "aws_s3_bucket" "s3_bucket_splunk_license" {
  bucket = var.splunk_license_s3_bucket_name
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.s3key.arn
        sse_algorithm = "aws:kms"
      }
    }
  }
  tags = {
    Name = var.s3_bucket_name
  }
}