output "public_ip" {
  value = aws_instance.app.public_ip
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/devops-project-key.pem ec2-user@${aws_instance.app.public_ip}"
}

output "ecr_repository_urls" {
  value = { for name, repo in aws_ecr_repository.services : name => repo.repository_url }
}