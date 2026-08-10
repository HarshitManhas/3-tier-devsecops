output "public_ip"       { value = aws_eip.sonarqube.public_ip }
output "instance_id"     { value = aws_instance.sonarqube.id }
output "private_ip"      { value = aws_instance.sonarqube.private_ip }
output "sonarqube_url"   { value = "http://${aws_eip.sonarqube.public_ip}:9000" }
output "sg_id"           { value = aws_security_group.sonarqube.id }
