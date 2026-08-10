output "public_ip"    { value = aws_eip.jenkins.public_ip }
output "instance_id"  { value = aws_instance.jenkins.id }
output "private_ip"   { value = aws_instance.jenkins.private_ip }
output "jenkins_url"  { value = "http://${aws_eip.jenkins.public_ip}:8080" }
output "sg_id"        { value = aws_security_group.jenkins.id }
