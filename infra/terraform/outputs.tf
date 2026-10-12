output "coordinator_public_ip" {
  description = "IP publico do coordenador (SSH e servidores: REP/PUB/ventilator+sink)."
  value       = aws_instance.node[0].public_ip
}

output "coordinator_private_ip" {
  description = "IP privado do coordenador. E o valor de ZMQ_HOST usado pelos nos."
  value       = aws_instance.node[0].private_ip
}

output "node_public_ips" {
  description = "IPs publicos dos nos (clientes/subscribers/workers)."
  value       = [for n in slice(aws_instance.node, 1, length(aws_instance.node)) : n.public_ip]
}

output "all_public_ips" {
  description = "IPs publicos de todas as instancias."
  value       = aws_instance.node[*].public_ip
}

output "ssh_key" {
  description = "Caminho da chave SSH privada gerada."
  value       = abspath(local_sensitive_file.pem.filename)
}
