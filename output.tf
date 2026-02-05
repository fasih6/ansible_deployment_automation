output "cluster_id" {
  value = aws_eks_cluster.devops1.id
}

output "node_group_id" {
  value = aws_eks_node_group.devops1.id
}

output "vpc_id" {
  value = aws_vpc.devops1_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.devops1_subnet[*].id
}

