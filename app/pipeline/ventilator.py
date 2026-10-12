import sys
import random
import zmq
from constPipe import *  #-

#
# Ventilator do pipeline (PUSH/PULL).
#
# Estende o exemplo da Fig. 4.23 do van Steen (uma fonte que empurrava cargas
# "fingidas" com sleep) para um pipeline paralelo completo: o ventilator
# distribui N tarefas com trabalho de CPU REAL, os workers processam em paralelo
# e enviam o resultado ao sink.
#
# O socket PUSH faz balanceamento round-robin entre todos os workers conectados,
# entao quanto mais workers, maior a vazao -- sem mudar uma linha deste codigo.
#
# Uso: python3 ventilator.py [ntarefas]   (padrao 100)
#

ntarefas = int(sys.argv[1]) if len(sys.argv) > 1 else 100

context = zmq.Context()

sender = context.socket(zmq.PUSH)                      # distribui as tarefas
sender.bind("tcp://" + BIND + ":" + PORT_VENT)

sink = context.socket(zmq.PUSH)                        # canal de controle com o sink
sink.connect("tcp://" + HOST + ":" + PORT_SINK)

# "Slow joiner": o PUSH so distribui para quem ja esta conectado. Esperamos o
# operador confirmar que os workers subiram antes de disparar o lote.
input("Pressione Enter quando os workers estiverem prontos...")
print("Enviando %d tarefas" % ntarefas)

sink.send_string("START %d" % ntarefas)                # avisa o sink quantas esperar
for _ in range(ntarefas):
    n = random.randint(1000, 100000)                   # numero a ser analisado
    sender.send_string(str(n))                         # tarefa (balanceada entre workers)
print("Lote enviado.")
