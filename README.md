# OpenEMR Cybersecurity Systems Engineering Testbed
## EverWatch Start-up Guide

This section provides instructions for EverWatch installation and setup to get Kibana working and logs ingesting into Elasticsearch.

## 1. Start the stack

```bash
docker compose up -d
docker compose ps
```

Wait until `elasticsearch`, `kibana`, `logstash`, `filebeat`, `openemr_app`, and `openemr_mariadb` are all running.

## 2. Configure OpenEMR ATNA TLS logging (required for ATNA audit logs)

Open OpenEMR at http://localhost:8080 and log in:
- **Username:** `admin`
- **Password:** `pass`

> For remote deployment replace `localhost` with your host IP.

Go to **Admin → Config → Logging** and set:
- **Enable ATNA Auditing:** on
- **ATNA audit host:** `logstash`
- **ATNA audit port:** `6514`
- **ATNA audit local certificate:** `/etc/openemr/atna-certs/openemr-combined.pem`
- **ATNA audit CA certificate:** `/etc/openemr/atna-certs/ca.crt`
- **Enable Audit Log Encryption:** on

## 3. Import the EverWatch dashboard and security rules

The script polls until Kibana is ready, then imports:
- `EverWatchDashboard.ndjson` saved objects
- `rules_export.ndjson` Kibana Security detection rules

```bash
./import-dashboard.sh
```

> For a remote host: `KIBANA_URL=http://<host>:5601 ./import-dashboard.sh`

## 4. View the EverWatch Dashboard

Log in to Kibana at http://localhost:5601:
- **Username:** `elastic`
- **Password:** `CYSE587project!`

> For remote deployment replace `localhost` with your host IP.

- In the navigation pane, under **Analytics**, click **Dashboards**.
- Select **Login Dash**.

Generate test data by logging in and out of OpenEMR, then refresh the dashboard to confirm logs are flowing.

---

