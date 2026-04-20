#!/bin/sh
# Import EverWatch saved objects and Kibana Security detection rules into Kibana.
# Run from the project root after "docker compose up -d".
#
# Usage:  ./import-dashboard.sh
# Env vars can be overridden on the command line:
#   KIBANA_URL=http://localhost:5601 ELASTIC_PASSWORD=secret ./import-dashboard.sh

set -eu

KIBANA_URL="${KIBANA_URL:-http://localhost:5601}"
ELASTIC_PASSWORD="${ELASTIC_PASSWORD:-$(grep '^ELASTIC_PASSWORD=' .env | cut -d= -f2-)}"
NDJSON_FILE="${NDJSON_FILE:-EverWatchDashboard.ndjson}"
RULES_FILE="${RULES_FILE:-rules_export.ndjson}"
SAVED_OBJECTS_RESULT="/tmp/kibana_saved_objects_import.json"
RULES_RESULT="/tmp/kibana_rules_import.json"

if [ ! -f "$NDJSON_FILE" ]; then
  echo "ERROR: $NDJSON_FILE not found. Run this script from the project root."
  exit 1
fi

if [ ! -f "$RULES_FILE" ]; then
  echo "ERROR: $RULES_FILE not found. Run this script from the project root."
  exit 1
fi

echo "Waiting for Kibana to be ready at $KIBANA_URL ..."
until curl -s -o /dev/null -w "%{http_code}" \
    -u "elastic:${ELASTIC_PASSWORD}" \
    "${KIBANA_URL}/api/status" | grep -q "^200$"; do
  sleep 5
done

echo "Kibana is ready. Importing saved objects from $NDJSON_FILE ..."
saved_objects_status=$(curl -s -o "$SAVED_OBJECTS_RESULT" -w "%{http_code}" \
  -u "elastic:${ELASTIC_PASSWORD}" \
  -X POST "${KIBANA_URL}/api/saved_objects/_import?overwrite=true" \
  -H "kbn-xsrf: true" \
  --form "file=@${NDJSON_FILE}")

if [ "$saved_objects_status" = "200" ]; then
  echo "Saved objects import successful."
  if grep -q '"errors":true' "$SAVED_OBJECTS_RESULT" 2>/dev/null; then
    echo "WARNING: Some saved objects had errors:"
    cat "$SAVED_OBJECTS_RESULT"
  fi
else
  echo "ERROR: Saved objects import returned HTTP $saved_objects_status"
  cat "$SAVED_OBJECTS_RESULT"
  exit 1
fi

echo "Importing Kibana Security detection rules from $RULES_FILE ..."
rules_status=$(curl -s -o "$RULES_RESULT" -w "%{http_code}" \
  -u "elastic:${ELASTIC_PASSWORD}" \
  -X POST "${KIBANA_URL}/api/detection_engine/rules/_import?overwrite=true&overwrite_action_connectors=true" \
  -H "kbn-xsrf: true" \
  --form "file=@${RULES_FILE}")

if [ "$rules_status" = "200" ]; then
  echo "Kibana Security detection rules import successful."
  if grep -Eq '"errors"\s*:\s*true|"success"\s*:\s*false' "$RULES_RESULT" 2>/dev/null; then
    echo "WARNING: Some security rules had errors:"
    cat "$RULES_RESULT"
  fi
else
  echo "ERROR: Kibana Security detection rules import returned HTTP $rules_status"
  cat "$RULES_RESULT"
  exit 1
fi

echo "All imports completed."
