import sys
import zmq
from constPS import *  #-

#
# Subscriber da "estacao de sensores" (PUB/SUB).
#
# Recebe os topicos de interesse pela linha de comando e so enxerga o que casar:
#   python3 subscriber.py TEMP WIND     -> so temperatura e vento
#   python3 subscriber.py HUMID         -> so umidade
#   python3 subscriber.py               -> assina "" (curinga) = recebe TUDO
#
# A assinatura (SUBSCRIBE) e um filtro por PREFIXO aplicado pelo proprio socket
# SUB: mensagens que nao casam nunca sobem para a aplicacao. Varios subscribers
# podem ouvir o mesmo publisher, cada um com o seu recorte (desacoplamento 1-N).
#

context = zmq.Context()
s = context.socket(zmq.SUB)          # socket assinante
p = "tcp://" + HOST + ":" + PORT     # onde conectar
s.connect(p)

topicos = sys.argv[1:] if len(sys.argv) > 1 else [""]
for t in topicos:
    s.setsockopt_string(zmq.SUBSCRIBE, t)   # assina cada topico pedido

alvo = ", ".join(t if t else "<tudo>" for t in topicos)
print("Conectado em " + p + " | assinando: " + alvo)
while True:
    print(s.recv_string())           # recebe somente o que casa com a assinatura
