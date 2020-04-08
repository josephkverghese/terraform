output "publicsubnets" {
  value = aws_subnet.gtos_subnet_public.*.id
}

output "public_subnet_CIDRs" {
  value = aws_subnet.gtos_subnet_public.*.cidr_block
}

output "privatesubnets" {
  value = aws_subnet.gtos_subnet_private.*.id
}

output "private_subnet_CIDRs" {
  value = aws_subnet.gtos_subnet_private.*.cidr_block
}


output "gtos_vpc" {
  value = aws_vpc.gtosvpc.id
}

output "user_subnet" {
  value = aws_subnet.gtos_user_subnet.id
}

output "user_subnet_cidr" {
  value = aws_subnet.gtos_user_subnet.cidr_block
}