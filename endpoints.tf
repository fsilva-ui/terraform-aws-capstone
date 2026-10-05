# Gateway endpoint allows resources in the VPC to reach S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.dr.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.public.id
  ]

  tags = {
    Name        = "capstone-s3-endpoint"
    Environment = "lab"
    Project     = "AWS Cloud Capstone"
  }
}