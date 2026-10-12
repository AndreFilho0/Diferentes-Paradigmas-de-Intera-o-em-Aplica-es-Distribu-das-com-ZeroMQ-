import os

# Pipeline (PUSH/PULL): ventilator -> workers -> sink.
#
# O ventilator e o sink ficam na maquina COORDENADORA; os workers conectam
# nela. Nos workers, exporte ZMQ_HOST com o IP do coordenador (o Ansible ja faz
# isso ao provisionar):
#   export ZMQ_HOST=10.0.1.23
HOST = os.environ.get("ZMQ_HOST", "localhost")  # IP do coordenador (para os WORKERS)
BIND = "*"                                       # interface do ventilator e do sink
PORT_VENT = os.environ.get("ZMQ_PORT_VENT", "5557")  # ventilator PUSH -> workers PULL
PORT_SINK = os.environ.get("ZMQ_PORT_SINK", "5558")  # workers PUSH    -> sink PULL
