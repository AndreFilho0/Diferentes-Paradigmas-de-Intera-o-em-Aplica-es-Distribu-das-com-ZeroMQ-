import os

# Request-Reply (REQ/REP).
#
# O SERVIDOR faz bind em todas as interfaces (BIND = "*"); o CLIENTE conecta
# no endereco HOST. Em maquinas diferentes (ex.: EC2), exporte no cliente o IP
# do servidor -- o Ansible ja faz isso automaticamente ao provisionar:
#   export ZMQ_HOST=10.0.1.23
HOST = os.environ.get("ZMQ_HOST", "localhost")  # para onde o CLIENTE conecta
BIND = "*"                                       # onde o SERVIDOR escuta
PORT = os.environ.get("ZMQ_PORT_REQREP", "5555")
