import sys
import zmq
from constCS import *  #-

#
# Cliente Request-Reply (REQ/REP) do key-value store.
#
# Abre um prompt onde o usuario digita os comandos (SET/GET/DEL/INCR/KEYS).
# Tambem aceita um comando unico pela linha de comando, util para scripts:
#   python3 client.py SET nome andre
#   python3 client.py GET nome
#
# QUIT encerra apenas o cliente; STOP encerra o servidor.
#

context = zmq.Context()
s = context.socket(zmq.REQ)          # socket de requisicao (request)
p = "tcp://" + HOST + ":" + PORT     # onde conectar
s.connect(p)                         # bloqueia ate conectar


def pedir(linha):
    s.send_string(linha)             # envia a requisicao
    print(s.recv_string())           # bloqueia ate a resposta (lockstep)


# Modo "um tiro": executa o comando passado por argumento e sai.
if len(sys.argv) > 1:
    pedir(" ".join(sys.argv[1:]))
    sys.exit(0)

# Modo interativo.
print("Conectado em " + p)
print("Comandos: SET <k> <v> | GET <k> | DEL <k> | INCR <k> | KEYS | STOP | QUIT")
while True:
    try:
        linha = input("> ").strip()
    except EOFError:
        break
    if not linha:
        continue
    if linha.upper() == "QUIT":      # sai so do cliente; servidor continua no ar
        break
    pedir(linha)
    if linha.upper() == "STOP":      # servidor encerrou; nada mais a fazer
        break
