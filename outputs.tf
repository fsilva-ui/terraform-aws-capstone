output "vpc_id" {
  description = "ID of the disaster recovery VPC"
  value       = aws_vpc.dr.id
}

output "public_subnet_ids" {
  description = "Public subnets IDs"
  value = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
}

output "private_subnet_ids" {
  description = "Private application subnets IDs"
  value = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]
}

output "data_subnet_ids" {
  description = "Private data subnets IDs"
  value = [
    aws_subnet.data_a.id,
    aws_subnet.data_b.id
  ]
}