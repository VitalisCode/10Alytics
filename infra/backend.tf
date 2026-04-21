terraform {
  backend "s3" {
    bucket         = "10alytics-tf-state-bucket"
    key            = "eks-project/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}