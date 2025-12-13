locals {
  // bucket name：cloud-native-etl-data-dev 這種形式
  bucket_name = "${var.project_name}-data-${var.env}"
  common_tags = {
    Project = var.project_name
    Env     = var.env
    Managed = "terraform"
  }
}

resource "aws_s3_bucket" "data" {
  bucket = local.bucket_name

  force_destroy = true

  tags = local.common_tags
}

resource "aws_s3_object" "raw_prefix_placeholder" {
  bucket  = aws_s3_bucket.data.id
  key     = "raw/"
  content = ""

  depends_on = [aws_s3_bucket.data]
}

resource "aws_s3_object" "curated_prefix_placeholder" {
  bucket  = aws_s3_bucket.data.id
  key     = "curated/"
  content = ""

  depends_on = [aws_s3_bucket.data]
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    id     = "raw-expire"
    status = "Enabled" // 啟用保留

    filter {
      prefix = "raw/"
    }

    expiration {
      days = 30
    }
  }

  rule {
    id     = "curated-expire"
    status = "Enabled" // 啟用保留

    filter {
      prefix = "curated/"
    }

    expiration {
      days = 180
    }
  }
}

# 跨帳號存取時常用的 Ownership 設定
resource "aws_s3_bucket_ownership_controls" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
