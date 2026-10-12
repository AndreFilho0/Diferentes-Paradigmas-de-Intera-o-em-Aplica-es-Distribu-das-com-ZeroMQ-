import time
import zmq
from constPipe import *  #-

#
# Sink do pipeline (PUSH/PULL).
#
# Recebe primeiro a mensagem de controle "START <n>" do ventilator, depois
# coleta os n resultados vindos dos workers, soma tudo e mostra quantas tarefas
# cada worker processou -- evidencia visivel do balanceamento de carga.
#
# Deve ser iniciado ANTES do ventilator (ele faz bind; o ventilator conecta).
#

context = zmq.Context()
receiver = context.socket(zmq.PULL)                     # recebe START e resultados
receiver.bind("tcp://" + BIND + ":" + PORT_SINK)

print("Sink pronto, aguardando o ventilator...")
cabecalho = receiver.recv_string().split()              # espera "START <n>"
total_tarefas = int(cabecalho[1])
print("Coletando %d resultados..." % total_tarefas)

inicio = time.time()
total = 0
por_worker = {}
for _ in range(total_tarefas):
    worker, n, r = receiver.recv_string().split()
    total += int(r)
    por_worker[worker] = por_worker.get(worker, 0) + 1

print("Concluido em %.2fs" % (time.time() - inicio))
print("Soma de todos os resultados: %d" % total)
print("Tarefas por worker:")
for w in sorted(por_worker):
    print("  worker %s: %d tarefas" % (w, por_worker[w]))
