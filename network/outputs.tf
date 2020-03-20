output "publicsubnets" {
  value = aws_subnet.gtos_public_subnet.*.id
}

output "sg" {
  value = aws_security_group.gtos_public_sg.id
}

output "gtos_vpc" {
  value = aws_vpc.gtosvpc.id
}

output "user_subnet" {
  value = aws_subnet.gtos_user_subnet.id
}
