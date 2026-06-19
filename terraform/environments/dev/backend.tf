terraform {
  backend "s3" {
    bucket         = "microservices-demo-tfstate-803146828684-ap-south-1"
    key            = "environments/dev/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "microservices-demo-tfstate-lock"
  }
}
