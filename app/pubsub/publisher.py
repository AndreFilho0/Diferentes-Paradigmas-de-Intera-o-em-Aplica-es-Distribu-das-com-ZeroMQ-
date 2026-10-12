import time
import random
import zmq
from constPS import *  #-

#
# Publisher da "estacao de sensores" (PUB/SUB).
#
# Estende o exemplo da Fig. 4.22 do van Steen (que publicava apenas a hora no
# topico TIME) para emitir VARIOS topicos. A cada segundo publica uma rajada de
# tres leituras simuladas, cada uma com numero de sequencia e horario:
#
#   TEMP  #<seq> <hora> <valor>     temperatura em graus C
#   HUMID #<seq> <hora> <valor>     umidade relativa em %
#   WIND  #<seq> <hora> <valor>     vento em km/h
#
# O publisher NAO sabe quem esta ouvindo (desacoplamento no espaco) e manda tudo
# para a rede; a filtragem por topico acontece no lado do subscriber.
#

context = zmq.Context()
s = context.socket(zmq.PUB)          # socket publicador
p = "tcp://" + BIND + ":" + PORT     # onde publicar
s.bind(p)

print("Publicando sensores em " + p + " (Ctrl+C para parar)")
seq = 0
while True:
    time.sleep(1)                    # uma rajada de leituras por segundo
    seq += 1
    hora = time.strftime("%H:%M:%S")
    leituras = {
        "TEMP": "%.1f" % random.uniform(18, 32),
        "HUMID": "%.1f" % random.uniform(40, 90),
        "WIND": "%.1f" % random.uniform(0, 60),
    }
    for topico, valor in leituras.items():
        msg = "%s #%d %s %s" % (topico, seq, hora, valor)
        s.send_string(msg)           # o topico e o prefixo da mensagem
        print(msg)
