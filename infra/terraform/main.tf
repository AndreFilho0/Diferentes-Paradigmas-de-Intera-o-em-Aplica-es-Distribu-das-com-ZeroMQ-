# ---------------------------------------------------------------------------
# Imagem (AMI): Amazon Linux 2023 mais recente, x86_64.
# ---------------------------------------------------------------------------
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ---------------------------------------------------------------------------
# Rede: usamos a VPC/subnet padrao da conta para manter o projeto plug-and-play
# (sem precisar criar VPC, gateway, rotas etc.).
# ---------------------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ---------------------------------------------------------------------------
# Par de chaves SSH: gerado pelo Terraform e salvo localmente como <key>.pem.
# Assim ninguem precisa criar chave na mao -- o Ansible e o SSH ja a usam.
# ---------------------------------------------------------------------------
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = var.key_name
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "local_sensitive_file" "pem" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/${var.key_name}.pem"
  file_permission = "0400"
}

# ---------------------------------------------------------------------------
# Security group: libera SSH (22) e as portas ZeroMQ (5555-5558).
# Aberto para 0.0.0.0/0 por conveniencia de teste (conta descartavel com
# credito). Em uso real, restrinja ao seu IP.
# ---------------------------------------------------------------------------
resource "aws_security_group" "zmq" {
  name        = "${var.project}-sg"
  description = "SSH e portas ZeroMQ (REQ/REP, PUB/SUB, pipeline)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Portas ZeroMQ (acesso externo, ex.: cliente no laptop)"
    from_port   = 5555
    to_port     = 5558
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Libera TODO o trafego entre instancias que usam este mesmo security group.
  # E o idioma padrao da AWS para "deixar as maquinas do grupo conversarem entre
  # si" dentro da VPC (coordenador <-> nos, em qualquer porta ZeroMQ).
  ingress {
    description = "Trafego interno entre as maquinas do grupo"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Saida liberada"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-sg"
  }
}

# ---------------------------------------------------------------------------
# Instancias EC2. A de indice 0 e o coordenador; as demais sao nos.
# ---------------------------------------------------------------------------
resource "aws_instance" "node" {
  count                       = var.instance_count
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.this.key_name
  subnet_id                   = tolist(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids      = [aws_security_group.zmq.id]
  associate_public_ip_address = true

  tags = {
    Name = count.index == 0 ? "${var.project}-coordenador" : "${var.project}-no-${count.index}"
    Role = count.index == 0 ? "coordinator" : "node"
  }
}

# ---------------------------------------------------------------------------
# Inventario do Ansible gerado automaticamente a partir das instancias criadas.
# ---------------------------------------------------------------------------
resource "local_file" "inventory" {
  filename = "${path.module}/../ansible/inventory.ini"
  content = templatefile("${path.module}/inventory.tftpl", {
    coordinator_ip      = aws_instance.node[0].public_ip
    coordinator_private = aws_instance.node[0].private_ip
    node_ips            = [for n in slice(aws_instance.node, 1, length(aws_instance.node)) : n.public_ip]
    key_path            = abspath(local_sensitive_file.pem.filename)
  })
}
