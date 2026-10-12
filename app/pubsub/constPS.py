import os

# Publish-Subscribe (PUB/SUB).
#
# O PUBLISHER faz bind em todas as interfaces (BIND = "*"); cada SUBSCRIBER
# conecta no endereco HOST. Em maquinas diferentes, exporte no subscriber o IP
# do publisher (o Ansible ja cuida disso ao provisionar):
#   export ZMQ_HOST=10.0.1.23
HOST = os.environ.get("ZMQ_HOST", "localhost")  # para onde o SUBSCRIBER conecta
BIND = "*"                                       # onde o PUBLISHER publica
PORT = os.environ.get("ZMQ_PORT_PUBSUB", "5556")
