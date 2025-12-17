

# Jenkins Outputs
output "jenkins_public_ip" {
  description = "Public IP of Jenkins server"
  value       = aws_instance.jenkins.public_ip
}

output "jenkins_public_dns" {
  description = "Public DNS of Jenkins server"
  value       = aws_instance.jenkins.public_dns
}

output "jenkins_url" {
  description = "URL to access Jenkins"
  value       = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "jenkins_role_arn" {
  description = "ARN of the Jenkins IAM role"
  value       = aws_iam_role.jenkins.arn
}
