provider "aws" {
    region = "ap-southeast-1"
}

resource "aws_s3_bucket" "terraform_state" {
    bucket = "terraform-uar-nbilal-20180425"

versioning { enabled = true }

lifecycle { prevent_destroy = true }

}