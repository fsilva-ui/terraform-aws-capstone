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

output "public_alb_security_group_id" {
  description = "Security group ID for the public ALB"
  value       = aws_security_group.public_alb.id
}

output "public_app_security_group_id" {
  description = "Security group ID for public-facing applications"
  value       = aws_security_group.public_app.id
}

output "internal_app_security_group_id" {
  description = "Security group ID for internal-only applications"
  value       = aws_security_group.internal_app.id
}

output "data_security_group_id" {
  description = "Security group ID for private data services"
  value       = aws_security_group.data.id
}

output "nextcloud_dr_instance_id" {
  description = "ID of the Nextcloud disaster recovery instance"
  value       = aws_instance.nextcloud_dr.id
}

output "nextcloud_dr_public_ip" {
  description = "Public IP address of the Nextcloud disaster recovery instance"
  value       = aws_instance.nextcloud_dr.public_ip
}

output "nextcloud_dr_url" {
  description = "URL to access the Nextcloud disaster recovery instance"
  value       = "http://${aws_instance.nextcloud_dr.public_ip}"
}

output "nextcloud_dr_ami_id" {
  description = "AMI ID for Nextcloud DR recovery"
  value       = aws_ami_from_instance.nextcloud_dr.id
}

output "nextcloud_recovery_instance_id" {
  description = "Instance ID of the recovered Nextcloud DR instance"
  value       = aws_instance.nextcloud_recovery.id
}

output "nextcloud_recovery_public_ip" {
  description = "Public IP of the recovered Nextcloud DR instance"
  value       = aws_instance.nextcloud_recovery.public_ip
}

output "nextcloud_recovery_url" {
  description = "URL of the recovered Nextcloud DR instance"
  value       = "http://${aws_instance.nextcloud_recovery.public_ip}"
}