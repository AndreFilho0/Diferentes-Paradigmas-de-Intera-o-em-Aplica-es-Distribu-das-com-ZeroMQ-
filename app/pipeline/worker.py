import sys
import zmq
from constPipe import *  #-

#
# Worker do pipeline (PUSH/PULL).
#
# Puxa tarefas do ventilator (PULL), faz um trabalho de CPU de verdade -- somar
# os divisores do numero recebido -- e empurra o resultado para o sink (PUSH).
# Suba varios workers (em maquinas diferentes) para ver o paralelismo e o
# balanceamento de carga do ZeroMQ.
#
# Uso: python3 worker.py <id>     (ex.: worker.py A)
#


def soma_divisores(n):               # trabalho de CPU proposital (O(n))
    return sum(d for d in range(1, n + 1) if n % d == 0)


me = sys.argv[1] if len(sys.argv) > 1 else "1"

context = zmq.Context()

receiver = context.socket(zmq.PULL)                     # recebe tarefas do ventilator
receiver.connect("tcp://" + HOST + ":" + PORT_VENT)

sender = context.socket(zmq.PUSH)                       # envia resultados ao sink
sender.connect("tcp://" + HOST + ":" + PORT_SINK)

print("worker " + me + " pronto")
while True:
    n = int(receiver.recv_string())                     # bloqueia ate chegar tarefa
    r = soma_divisores(n)
    sender.send_string("%s %d %d" % (me, n, r))         # <worker> <n> <resultado>
