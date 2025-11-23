output "jenkins_url" {
  description = "URL to access Jenkins"
  value       = "http://${aws_eip.jenkins_eip.public_ip}:8080"
}

output "jenkins_ip" {
  description = "Elastic IP of Jenkins server"
  value       = aws_eip.jenkins_eip.public_ip
}

output "ssh_command" {
  description = "Command to SSH into Jenkins server"
  value       = "ssh -i my-key-pair.pem ec2-user@${aws_eip.jenkins_eip.public_ip}"
}