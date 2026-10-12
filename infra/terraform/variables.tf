variable "region" {
  description = "Regiao AWS onde as instancias serao criadas."
  type        = string
  default     = "us-east-1"
}

variable "instance_count" {
  description = "Numero de instancias. A de indice 0 e o coordenador; as demais sao nos (clientes/subscribers/workers)."
  type        = number
  default     = 3
}

variable "instance_type" {
  description = "Tipo da instancia EC2 (t3.micro e barato e suficiente para a demo)."
  type        = string
  default     = "t3.micro"
}

variable "project" {
  description = "Prefixo usado nos nomes dos recursos."
  type        = string
  default     = "zmq-paradigmas"
}

variable "key_name" {
  description = "Nome do par de chaves SSH criado na AWS (a chave privada e salva localmente)."
  type        = string
  default     = "zmq-key"
}
