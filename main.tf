provider "aws" {
    region = "ap-southeast-1"
}

resource "aws_instance" "example" {
    ami = "ami-e2adf99e"
    instance_type = "t2.micro"
    tags {
        Name = "terraform-example-02"
    }
}