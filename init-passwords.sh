#!/bin/sh
# Wait for Elasticsearch to be healthy AND cluster state recovered
until curl -f -s -u elastic:"${ELASTIC_PASSWORD}" http://elasticsearch:9200/_cluster/health >/dev/null 2>&1; do
  echo "Waiting for Elasticsearch to start..."
  sleep 5
done

# Additional wait: retry until security API is writable (cluster state fully recovered)
until result=$(curl -s -o /dev/null -w "%{http_code}" \
  -u elastic:"${ELASTIC_PASSWORD}" -X POST \
  http://elasticsearch:9200/_security/user/kibana_system/_password \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"${KIBANA_SYSTEM_PASSWORD}\"}"); \
  [ "$result" = "200" ]; do
  echo "Waiting for Elasticsearch security API (got HTTP $result)..."
  sleep 5
done

echo "kibana_system password set successfully"
