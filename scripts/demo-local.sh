#!/usr/bin/env bash
#
# Roda os tres paradigmas ZeroMQ na propria maquina (localhost), sem AWS.
# Util para desenvolver e para colegas testarem rapidinho.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PY="$ROOT/.venv/bin/python"
[ -x "$PY" ] || PY="python3"

echo "################ 1) REQ/REP - key-value store ################"
"$PY" app/reqrep/server.py >/tmp/zmq_srv.log 2>&1 &
SRV=$!
sleep 1
for c in "SET nome andre" "GET nome" "INCR visitas" "INCR visitas" "KEYS" "GET fantasma"; do
  printf '%s -> ' "$c"
  "$PY" app/reqrep/client.py $c
done
"$PY" app/reqrep/client.py STOP >/dev/null
wait $SRV 2>/dev/null || true

echo
echo "################ 2) PUB/SUB - filtragem por topico ################"
"$PY" app/pubsub/publisher.py >/tmp/zmq_pub.log 2>&1 &
PUB=$!
sleep 1
echo "-- subscriber assinando apenas TEMP e WIND (NAO deve aparecer HUMID):"
"$PY" - <<'PYEOF'
import zmq, os
os.chdir('app/pubsub')
from constPS import *
c = zmq.Context(); s = c.socket(zmq.SUB); s.connect('tcp://localhost:' + PORT)
for t in ('TEMP', 'WIND'):
    s.setsockopt_string(zmq.SUBSCRIBE, t)
for _ in range(6):
    print("   " + s.recv_string())
PYEOF
kill $PUB 2>/dev/null || true
wait $PUB 2>/dev/null || true

echo
echo "################ 3) PIPELINE - ventilator/workers/sink ################"
"$PY" app/pipeline/sink.py >/tmp/zmq_sink.log 2>&1 &
SINK=$!
"$PY" app/pipeline/worker.py A >/dev/null 2>&1 &
WA=$!
"$PY" app/pipeline/worker.py B >/dev/null 2>&1 &
WB=$!
sleep 1
echo "" | "$PY" app/pipeline/ventilator.py 60 >/dev/null 2>&1
wait $SINK 2>/dev/null || true
kill $WA $WB 2>/dev/null || true
wait $WA $WB 2>/dev/null || true
cat /tmp/zmq_sink.log
