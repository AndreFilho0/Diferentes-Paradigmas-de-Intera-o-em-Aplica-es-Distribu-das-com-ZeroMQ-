import zmq
from constCS import *  #-

#
# Servidor Request-Reply (REQ/REP) com um key-value store em memoria.
#
# Estende o exemplo da Fig. 4.21 do van Steen (que apenas devolvia a mensagem
# recebida acrescida de "*") para um servico de verdade, com estado compartilhado
# entre todos os clientes. O REQ/REP e um dialogo em lockstep: para cada
# requisicao recebida (recv) o servidor devolve exatamente uma resposta (send).
#
# Protocolo (uma linha de texto por requisicao):
#   SET <chave> <valor>   -> OK
#   GET <chave>           -> OK <valor>        | ERR chave inexistente
#   DEL <chave>           -> OK                 | ERR chave inexistente
#   INCR <chave>          -> OK <n>             (contador; cria em 0 se nao existir)
#   KEYS                  -> DATA <n> + <n> linhas, uma chave por linha
#   STOP                  -> OK bye             (encerra o servidor)
#

context = zmq.Context()
s = context.socket(zmq.REP)          # socket de resposta (reply)
p = "tcp://" + BIND + ":" + PORT     # onde escutar
s.bind(p)                            # publica o servico no endereco

store = {}                           # key-value store em memoria


def processar(linha):
    partes = linha.split(" ", 2)     # separa COMANDO ARG1 ARG2
    cmd = partes[0].upper()

    if cmd == "SET":
        if len(partes) < 3:
            return "ERR uso: SET <chave> <valor>"
        store[partes[1]] = partes[2]
        return "OK"

    if cmd == "GET":
        if len(partes) < 2:
            return "ERR uso: GET <chave>"
        if partes[1] not in store:
            return "ERR chave inexistente"
        return "OK " + store[partes[1]]

    if cmd == "DEL":
        if len(partes) < 2:
            return "ERR uso: DEL <chave>"
        if store.pop(partes[1], None) is None:
            return "ERR chave inexistente"
        return "OK"

    if cmd == "INCR":
        if len(partes) < 2:
            return "ERR uso: INCR <chave>"
        try:
            n = int(store.get(partes[1], "0")) + 1
        except ValueError:
            return "ERR valor nao numerico"
        store[partes[1]] = str(n)
        return "OK " + str(n)

    if cmd == "KEYS":
        chaves = sorted(store.keys())
        return "DATA " + str(len(chaves)) + "\n" + "\n".join(chaves)

    return "ERR comando desconhecido"


print("KV server ouvindo em " + p)
while True:
    msg = s.recv_string().strip()        # bloqueia ate chegar a requisicao
    print("req: " + msg)
    if msg.upper() == "STOP":
        s.send_string("OK bye")          # REP exige um send para cada recv
        break
    s.send_string(processar(msg))        # devolve a resposta (lockstep)
