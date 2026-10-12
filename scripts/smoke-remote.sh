#!/usr/bin/env bash
#
# Smoke-test remoto: roda os 3 paradigmas ZeroMQ nas instancias EC2 reais,
# com timeouts (nunca trava) e limpando os processos ao final.
# Le os IPs/chave direto das saidas do Terraform.
#
set -uo pipefail

TF_DIR="$(cd "$(dirname "$0")/../infra/terraform" && pwd)"
tf() { terraform -chdir="$TF_DIR" output -raw "$1"; }

KEY="$(tf ssh_key)"
COORD="$(tf coordinator_public_ip)"
PRIV="$(tf coordinator_private_ip)"

NODES=()
while IFS= read -r ip; do [ -n "$ip" ] && NODES+=("$ip"); done < <(
  terraform -chdir="$TF_DIR" output -json node_public_ips \
    | python3 -c 'import sys,json;[print(x) for x in json.load(sys.stdin)]')
N1="${NODES[0]}"
N2="${NODES[1]:-${NODES[0]}}"

SSH_OPTS=(-i "$KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
# roda um comando remoto: rexec <ip> <comando>
rexec() { ssh "${SSH_OPTS[@]}" "ec2-user@$1" "$2"; }
# ativa o venv antes do comando
venv() { echo "cd ~/zmq && source .venv/bin/activate && $*"; }

cleanup() {
  echo "-- limpando processos remotos..."
  for ip in "$COORD" "${NODES[@]}"; do
    rexec "$ip" 'pkill -f "app/reqrep|app/pubsub|app/pipeline" 2>/dev/null; true' >/dev/null 2>&1
  done
}
trap cleanup EXIT
cleanup   # comeca limpo

echo "Coordenador: $COORD (priv $PRIV) | Nos: ${NODES[*]}"
echo

# ===========================================================================
echo "############### 1) REQ/REP (key-value store) ###############"
rexec "$COORD" "$(venv 'nohup stdbuf -oL python app/reqrep/server.py >/tmp/srv.log 2>&1 </dev/null & sleep 1; echo server_ok')"

echo "-- (diagnostico) cliente LOOPBACK no proprio coordenador (127.0.0.1):"
rexec "$COORD" "export ZMQ_HOST=127.0.0.1 && $(venv 'timeout 10 python app/reqrep/client.py SET loop ok'); echo exit=\$?"

echo "-- cliente CROSS-MACHINE do no $N1 -> coordenador ($PRIV):"
rexec "$N1" "export ZMQ_HOST=$PRIV && $(venv '
  timeout 10 python app/reqrep/client.py SET nome andre;
  timeout 10 python app/reqrep/client.py INCR visitas;
  timeout 10 python app/reqrep/client.py INCR visitas;
  timeout 10 python app/reqrep/client.py GET nome;
  timeout 10 python app/reqrep/client.py KEYS'); echo exit=\$?"

echo "-- encerrando o server (STOP):"
rexec "$N1" "export ZMQ_HOST=$PRIV && $(venv 'timeout 10 python app/reqrep/client.py STOP')"
echo "-- log do servidor:"
rexec "$COORD" 'cat /tmp/srv.log'
echo

# ===========================================================================
echo "############### 2) PUB/SUB (estacao de sensores) ###############"
rexec "$COORD" "$(venv 'nohup stdbuf -oL python app/pubsub/publisher.py >/tmp/pub.log 2>&1 </dev/null & sleep 1; echo publisher_ok')"

echo "-- subscriber no no $N1 assinando TEMP WIND (~6s; NAO deve ter HUMID):"
rexec "$N1" "export ZMQ_HOST=$PRIV && $(venv 'timeout 6 stdbuf -oL python app/pubsub/subscriber.py TEMP WIND'); true"
echo

# ===========================================================================
echo "############### 3) PIPELINE (ventilator/workers/sink) ###############"
# workers em background nos dois nos
rexec "$N1" "export ZMQ_HOST=$PRIV && $(venv 'nohup python app/pipeline/worker.py A >/tmp/wk.log 2>&1 </dev/null & echo worker_A_ok')"
rexec "$N2" "export ZMQ_HOST=$PRIV && $(venv 'nohup python app/pipeline/worker.py B >/tmp/wk.log 2>&1 </dev/null & echo worker_B_ok')"
# sink em background no coordenador
rexec "$COORD" "$(venv 'nohup stdbuf -oL python app/pipeline/sink.py >/tmp/sink.log 2>&1 </dev/null & sleep 1; echo sink_ok')"
# ventilator no coordenador (Enter automatico via echo)
echo "-- disparando 120 tarefas..."
rexec "$COORD" "export ZMQ_HOST=$PRIV && $(venv 'echo | timeout 30 python app/pipeline/ventilator.py 120'); true"
sleep 2
echo "-- resultado do sink:"
rexec "$COORD" 'cat /tmp/sink.log'
echo

echo "############### FIM ###############"
