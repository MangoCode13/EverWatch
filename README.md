# OpenEMR Cybersecurity Systems Engineering Testbed
## EverWatch Start-up Guide

This section is the minimum, straightforward setup to get Kibana working and logs ingesting into Elasticsearch.

## 1. Set required values in .env

Set these before first startup:

```dotenv
ELASTIC_PASSWORD=ChangeThisElasticPassword #This is your EverWatch Dashboard admin password for remote login!
KIBANA_SYSTEM_PASSWORD=ChangeThisKibanaSystemPassword
KIBANA_ENCRYPTEDSAVEDOBJECTS_KEY=UseAtLeast32CharactersAndKeepItStable
KIBANA_SECURITY_SESSION_KEY=UseAtLeast32CharactersAndKeepItStable
KIBANA_REPORTING_KEY=UseAtLeast32CharactersAndKeepItStable
KIBANA_ALLOWED_HOSTS=["smtp.internal.local","hooks.internal.local"]
```

Notes:
- The three Kibana keys must be stable and at least 32 characters.
- `KIBANA_ALLOWED_HOSTS` should include only trusted internal connector targets.

## 2. Start the stack

```bash
docker compose up -d
docker compose ps
```

Wait until `elasticsearch`, `kibana`, `logstash`, `filebeat`, `openemr_app`, and `openemr_mariadb` are running.

## 3. Bootstrap kibana_system password (required)

Run once (or anytime you change `KIBANA_SYSTEM_PASSWORD`):

```bash
set -a && source .env && set +a

curl -u elastic:"$ELASTIC_PASSWORD" -X POST \
    http://localhost:9200/_security/user/kibana_system/_password \
    -H 'Content-Type: application/json' \
    -d "{\"password\":\"$KIBANA_SYSTEM_PASSWORD\"}"

printf '%s' "$KIBANA_SYSTEM_PASSWORD" | docker compose run --rm -T kibana \
    bin/kibana-keystore add elasticsearch.password --stdin --force

docker compose restart kibana
```

## 4. Configure OpenEMR ATNA TLS logging (required for ATNA logs)

Open OpenEMR: http://localhost:8080 (admin / pass)
Note: For remote deployment replace localhost with the IP address of your remote host. 

Go to Admin -> Config -> Logging and set:
- Enable ATNA Auditing: on
- ATNA audit host: `logstash`
- ATNA audit port: `6514`
- ATNA audit local certificate: `/etc/openemr/atna-certs/openemr-combined.pem`
- ATNA audit CA certificate: `/etc/openemr/atna-certs/ca.crt`
- Enable Audit Log Encryption: on

Save and, if needed, restart OpenEMR:

```bash
docker compose restart openemr
```

## 5. Verify Kibana and ingestion

Run quick health checks:

```bash
set -a && source .env && set +a

curl -u elastic:"$ELASTIC_PASSWORD" http://localhost:5601/api/status
# Confirm log pipeline is receiving/parsing logs.
docker compose logs kibana --tail=80
docker compose logs filebeat --tail=80
docker compose logs logstash --tail=80
```

## 6. EverWatch Dashboard -- Import alterts and data views

Login to Kibana (http://localhost:5601):
Note: For remote deployment replace 'localhost' with the remote host IP address. 
- Log in as `elastic` with `ELASTIC_PASSWORD`.

Import the EverWatch Dashboard and saved objects:
- Open the navigation pane using the hamburger menu in the top-left, then click **Stack Management**.  
- Under **Kibana**, select **Saved Objects**.  
- Click **Import**.  
- Select the `EverWatchDashboard.ndjson` from the repository root.
- Complete the import prompts.

### EverWatch Dashboard
- In the navigation pane, under **Analytics**, click **Dashboards**.  
- Select **Login Dash**.

After import:
- Login to OpenEMR to generate logs.
- Open Discover and select the imported data view.
- Open Dashboards and confirm the imported dashboard loads.

---

