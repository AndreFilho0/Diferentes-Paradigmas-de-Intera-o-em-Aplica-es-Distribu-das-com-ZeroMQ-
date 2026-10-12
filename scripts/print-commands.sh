#!/usr/bin/env bash
#
# Le as saidas do Terraform e imprime os comandos prontos (copie e cole) para
# rodar cada paradigma ZeroMQ nas instancias EC2 criadas.
#
set -euo pipefail

TF_DIR="$(cd "$(dirname "$0")/../infra/terraform" && pwd)"
tf() { terraform -chdir="$TF_DIR" output -raw "$1"; }

KEY="$(tf ssh_key)"
COORD="$(tf coordinator_public_ip)"
COORD_PRIV="$(tf coordinator_private_ip)"

NODES=()
while IFS= read -r ip; do
  [ -n "$ip" ] && NODES+=("$ip")
done < <(terraform -chdir="$TF_DIR" output -json node_public_ips \
          | python3 -c 'import sys,json;[print(x) for x in json.load(sys.stdin)]')

SSH="ssh -i $KEY -o StrictHostKeyChecking=no"
N1="${NODES[0]:-<no-1>}"
N2="${NODES[1]:-$N1}"

cat <<EOF

=====================================================================
 ZeroMQ - comandos prontos (copie e cole)
=====================================================================
 Chave SSH   : $KEY
 Coordenador : $COORD   (IP privado p/ os nos: $COORD_PRIV)
 Nos         : ${NODES[*]:-nenhum}

 Em qualquer maquina, depois do SSH, ative o ambiente com o atalho:
     zmq        # entra em ~/zmq e ativa o virtualenv (ZMQ_HOST ja esta setado)

---------------------------------------------------------------------
 1) REQ/REP  -  key-value store (cliente <-> servidor, lockstep)
---------------------------------------------------------------------
 Coordenador (servidor):
     $SSH ec2-user@$COORD
     zmq && python app/reqrep/server.py

 No 1 (cliente interativo):
     $SSH ec2-user@$N1
     zmq && python app/reqrep/client.py
       > SET nome andre
       > INCR visitas
       > KEYS
       > STOP

---------------------------------------------------------------------
 2) PUB/SUB  -  estacao de sensores (1 publisher, N subscribers)
---------------------------------------------------------------------
 Coordenador (publisher):
     $SSH ec2-user@$COORD
     zmq && python app/pubsub/publisher.py

 No 1 (subscriber so de TEMP e WIND):
     $SSH ec2-user@$N1
     zmq && python app/pubsub/subscriber.py TEMP WIND

 No 2 (subscriber curinga, recebe tudo):
     $SSH ec2-user@$N2
     zmq && python app/pubsub/subscriber.py

---------------------------------------------------------------------
 3) PIPELINE  -  ventilator -> workers -> sink (PUSH/PULL)
---------------------------------------------------------------------
 Coordenador, terminal A (sink - inicie primeiro):
     $SSH ec2-user@$COORD
     zmq && python app/pipeline/sink.py

 No 1 (worker A)  e  No 2 (worker B):
     $SSH ec2-user@$N1
     zmq && python app/pipeline/worker.py A
     ----
     $SSH ec2-user@$N2
     zmq && python app/pipeline/worker.py B

 Coordenador, terminal B (ventilator - por ultimo; da Enter quando os workers subirem):
     $SSH ec2-user@$COORD
     zmq && python app/pipeline/ventilator.py 200

=====================================================================
EOF
