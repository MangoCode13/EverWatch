# **EverWatch – Cybersecurity Systems Engineering Tool for OpenEMR**

<p align="center">
  <img src="logo/log.png" alt="EverWatch Logo" width="500">
</p>

---

## **Table of Contents**

| # | Section |
|---|---------|
| **1** | [System Description and Architecture Overview](#1-system-description-and-architecture-overview) |
| | [1.4 – Repository Provenance and Contribution Scope](#14-repository-provenance-and-contribution-scope) |
| **2** | [EverWatch Start-up Guide](#2-everwatch-start-up-guide) |
| | [2.0 – Environment Configuration](#20-environment-configuration) |
| **3** | [Execution and Demo Instructions](#3-execution-and-demo-instructions) |
| **4** | [Expected Outputs](#4-expected-outputs) |

---

## 1. System Description and Architecture Overview

### 1.1 Overview

EverWatch is a standalone, external cybersecurity governance and decision-support tool designed to monitor an OpenEMR-based Hospital Information System (HIS). Its mission is to collect, correlate, and interpret system evidence so that authorized stakeholders—such as IT security staff, privacy officers, and administrators—can make timely, well-informed oversight decisions. EverWatch leverages data analytics and customized algorithms to automate log review to detect security threats and potential misuse of patient health information. These detections would be impossible to conduct manually because of the sheer volume of logs generated—thousands per minute.

EverWatch operates strictly as an **external monitoring layer**. It does **not** modify OpenEMR source code, alter database schemas, interfere with authentication logic, or act as an inline enforcement mechanism. By remaining outside the clinical workflow path, it avoids introducing operational risk while still transforming raw telemetry into actionable governance outputs such as ranked risk indicators, evidence summaries, and alerts. The alert thresholds are calculated to maximize threat detection while eliminating alert fatigue.

---

### 1.2 Core Architectural Pillars

#### 1.2.1 Infrastructure

- Deployed as a Docker-containerized environment.
- Built on the **ELK stack** (Elasticsearch, Logstash, Kibana) with **Filebeat** for log shipping.
- Designed for modularity, portability, and clear separation from the OpenEMR runtime environment.

#### 1.2.2 Data Flows and Inputs

EverWatch relies exclusively on **read-only sources, managed externally from OpenEMR**. Primary inputs include:

- **OpenEMR ATNA audit logs** transmitted via the native auditing API using secure syslog (TLS over port 6514) into Logstash.  
(OpenEMR ATNA audit logs → Logstash → Elasticsearch\EverWatch) 
- **OpenEMR Apache web server logs** extracted from the OpenEMR container by Filebeat.  
(OpenEMR Apache web server logs → Filebeat → Elasticsearch\EverWatch) 
- **Optional enrichment feeds**, such as external threat intelligence or vulnerability data.

These inputs are correlated to produce governance-oriented outputs. EverWatch generates:

- Real-time security and privacy threat detection alerts
- Prioritized evidence summaries and artifacts
- Ranked risk indicators
- Plain-language explanations and investigation cues

All analytics results are presented in a centralized dashboard. The dashboard visualizes correlated activity patterns and issues alerts—such as excessive record access or anomalous geographic logins—mapped to MITRE ATT&CK tactics and paired with investigation guidance. 

---

### 1.3 Trust Boundaries

The EverWatch architecture is defined by **three distinct trust boundaries**, each representing a shift in control, authority, or security assumptions:

1. **OpenEMR → EverWatch**
   Separates the mission-critical clinical HIS from the external monitoring and decision-support domain. EverWatch receives only read-only telemetry and cannot interfere with clinical operations.

2. **EverWatch → Analysts**
   Separates the analytics environment from the human reviewers who access the dashboard. This boundary relies on strict role-based access control, authenticated sessions, and controlled exposure of sensitive evidence.

3. **EverWatch → External Feeds**
   Separates the internal analytics engine from optional external enrichment sources. This boundary ensures that external data cannot compromise the integrity or confidentiality of HIS-derived evidence.

---

### 1.4 Repository Provenance and Contribution Scope

This repository is a fork of [kabartsjc/cyseOpenEMR](https://github.com/kabartsjc/cyseOpenEMR), which provides a baseline OpenEMR deployment used as the monitored system under test. EverWatch is built as an independent monitoring layer on top of that foundation and does not modify any upstream OpenEMR application code.

#### Inherited from upstream (`kabartsjc/cyseOpenEMR`)

| File | Role |
|------|------|
| `docker-compose.yml` | Base OpenEMR + MariaDB service definitions (extended by EverWatch) |
| `LICENSE` | Project license |

#### Added or substantially rewritten by EverWatch

| File / Directory | EverWatch Contribution |
|------------------|------------------------|
| `docker-compose.yml` | Extended with Elasticsearch, Kibana, Logstash, and Filebeat service definitions |
| `filebeat.yml` | Filebeat input/output configuration for Apache log shipping |
| `logstash/pipeline/logstash.conf` | Full Logstash pipeline: ATNA syslog ingestion, grok parsing, GeoIP enrichment, and Elasticsearch output |
| `logstash_certs/` | TLS certificate authority and client/server certificates for ATNA mutual-TLS |
| `EverWatchDashboard.ndjson` | Kibana saved-objects export (dashboard panels, index patterns, visualizations) |
| `rules_export.ndjson` | Kibana Security detection rules (failed logins, out-of-state logins, record misuse) |
| `import-dashboard.sh` | Automated script to wait for Kibana readiness and import dashboards and rules |
| `init-passwords.sh` | Helper script to initialise Elasticsearch built-in user passwords |
| `autostart/` | systemd service unit and installer for unattended stack startup |
| `scripts/` | Supporting operational scripts |
| `geoip-db/` | MaxMind GeoLite2 City database for login geolocation enrichment |
| `logo/` | EverWatch branding assets |
| `.env.example` | Credential template (`.env` excluded from version control) |

---

## 2. EverWatch Start-up Guide

This section provides instructions for EverWatch installation and setup to get Kibana working and logs ingesting into Elasticsearch. EverWatch requires the same dependencies as the OpenEMR environment. Follow the [parent repo](https://github.com/kabartsjc/cyseOpenEMR) for Docker and environment setup.

---

### 2.0 Environment Configuration

> **Required before first run** — credentials are not stored in the repository.

1. Copy the template to create your local environment file:

   ```bash
   cp .env.example .env
   ```

2. Open `.env` and replace every `change_me_*` placeholder with a strong, unique value:
   - `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD` — MariaDB credentials
   - `OPENEMR_ADMIN_PASS` — OpenEMR web-UI admin password
   - `ELASTIC_PASSWORD` — Elasticsearch superuser password (8+ chars)
   - `KIBANA_SYSTEM_PASSWORD` — Kibana service-account password
   - `KIBANA_ENCRYPTEDSAVEDOBJECTS_KEY`, `KIBANA_SECURITY_SESSION_KEY`, `KIBANA_REPORTING_KEY` — must each be **32 or more characters**

> `.env` is excluded by `.gitignore`.

---

### 2.1 Start the Stack

```bash
docker compose up -d
docker compose ps
```

Wait until `elasticsearch`, `kibana`, `logstash`, `filebeat`, `openemr_app`, and `openemr_mariadb` are all running.

---

### 2.2 Configure OpenEMR ATNA TLS Logging

> **Required for ATNA audit logs**

Open OpenEMR at `http://localhost:8080` and log in:

- **Username:** value of `OPENEMR_ADMIN_USER` in your `.env` (default: `admin`)
- **Password:** value of `OPENEMR_ADMIN_PASS` in your `.env`

> For remote deployment replace `localhost` with your host IP.

Go to **Admin → Config → Logging** and set:

| Setting | Value |
|---------|-------|
| **Enable ATNA Auditing** | ✅ |
| **ATNA audit host** | `logstash` |
| **ATNA audit port** | `6514` |
| **ATNA audit local certificate** | `/etc/openemr/atna-certs/openemr-combined.pem` |
| **ATNA audit CA certificate** | `/etc/openemr/atna-certs/ca.crt` |
| **Enable Audit Log Encryption** | ✅ |

Save and, if needed, restart OpenEMR:

```bash
docker compose restart openemr_app
```

---

### 2.3 Verify Kibana and Log Ingestion

```bash
docker compose logs kibana --tail=40
docker compose logs filebeat --tail=40
docker compose logs logstash --tail=40
```

---

### 2.4 Import the EverWatch Dashboard and Security Rules

The script polls until Kibana is ready, then imports:

- `EverWatchDashboard.ndjson` saved objects
- `rules_export.ndjson` Kibana Security detection rules

```bash
./import-dashboard.sh
```

> For a remote host: `KIBANA_URL=http://<host>:5601 ./import-dashboard.sh`

---

### 2.5 View the EverWatch Dashboard

Log in to Kibana at `http://localhost:5601`:

- **Username:** `elastic`
- **Password:** value of `ELASTIC_PASSWORD` in your `.env`

> For remote deployment replace `localhost` with your host IP.

**Steps:**

1. In the navigation pane, under **Analytics**, click **Dashboards**.
2. Select **Login Dash**.

Generate test data by logging into OpenEMR, then refresh the dashboard to confirm logs are flowing.

---

## 3. Execution and Demo Instructions

### 3.1 Dashboard Access

Once the EverWatch environment is fully deployed, the governance dashboard—implemented in Kibana—is available to authorized users on **port 5601**. Access is provided through a standard web browser and requires valid credentials tied to the analyst or administrator role.

---

### 3.2 Demonstration Scenarios (Threat Detection)

After EverWatch begins ingesting OpenEMR audit logs and Apache web server telemetry, the system continuously evaluates activity patterns across the defined trust boundaries. To demonstrate its detection capabilities, access the OpenEMR web application to trigger several predefined threshold rules by logging in and interacting with patient records. Below are three security and privacy detection rules customized for OpenEMR.

#### 3.2.1 Failed Login Attempts

Detects repeated unsuccessful authentication attempts for a specific user within a defined time window.
This scenario simulates brute-force or password-guessing behavior.

#### 3.2.2 Out-of-State Logins

Maps the IP address of each successful login to its geographic location.
An alert is generated when a login originates from outside the designated state or region associated with the healthcare organization.

#### 3.2.3 Misuse of Patient Records

Identifies when a legitimate clinician accesses an unusually high number of patient records in a short period.
This scenario demonstrates insider-threat detection, such as snooping or unauthorized curiosity-driven access.

---

### 3.3 Analyst Workflow Demonstration

For each triggered scenario, EverWatch automatically:

- Alerts security analysts of the rule violated
- Generates a **plain-language investigation guide** within the dashboard
- Presents correlated evidence (logs, timestamps, user identifiers, geolocation data) in a unified view
- Maps the activity to relevant **MITRE ATT&CK tactics**
- Provides a predefined **risk score** for each alert based on severity and context

These workflows illustrate how EverWatch supports rapid triage, structured investigation, and governance-level decision-making without interfering with clinical operations.

---

## 4. Expected Outputs

EverWatch correlates and processes ingested audit and web-server logs to produce timely, human-usable governance information for authorized stakeholders—including IT security staff, privacy officers, and compliance personnel. The system outputs a unified dashboard, decision-support alerts, and structured metadata that guide analysts through rapid triage and investigation.

---

### 4.1 Dashboard View

A centralized observability interface that visualizes key telemetry, including:

- Attempted and successful logins by user
- Patient-record access patterns and volume metrics
- Geographic distribution of login activity
- High-level summaries of correlated security events

This dashboard provides reviewers with an immediate situational picture of system behavior across trust boundaries.

---

### 4.2 Decision-Support Alerts and Risk Reports

EverWatch generates governance-oriented outputs that summarize evidence, rank risk, and provide plain-language explanations from thousands of logs generated every few minutes. Core alert types include:

#### 4.2.1 Failed Login Attempts

Tracks repeated unsuccessful authentication attempts for a specific user within a defined timeframe.
Useful for identifying brute-force activity or compromised credentials.

#### 4.2.2 Out-of-State Logins

Maps successful login IP addresses to geographic locations and triggers when access originates outside the organization's designated state or region.
Supports detection of anomalous or suspicious remote access.

#### 4.2.3 Misuse of Patient Records (Excessive Curiosity)

Detects when a legitimate clinician accesses an unusually high number of patient records in a short period.
Highlights potential insider misuse, privacy violations, or data-exfiltration behavior.

---

### 4.3 Actionable Alert Metadata

Each alert generated by EverWatch includes:

- A mapped **MITRE ATT&CK tactic**
- A concise **investigation guide**
- Key artifacts of interest (usernames, IP addresses, timestamps, etc.)
- A **risk score** indicating relative severity

This metadata enables analysts to quickly understand context, prioritize response, and follow a structured review workflow.

---

### 4.4 Example Alert Output Table

| **Time Stamp** | **Rule Name** | **Investigation Guide** | **MITRE ATT&CK Tactic** | **Artifact of Interest** | **Relative Threat Score** |
|---|---|---|---|---|---|
| Apr 24, 2026 @ 13:48:43.287 | Out-of-State Login | Monitor account for unusual or high-risk activity; correlate with recent authentication history. | Initial Access | 216.24.219.251 | 25 |
| Apr 24, 2026 @ 13:43:43.262 | Clinician Access to Patient Records | Review access logs for this user to assess potential misuse of patient records. | Exfiltration | doctor1 | 75 |
| Apr 24, 2026 @ 13:38:40.558 | Failed Logins | Review the source of failed attempts; monitor for any subsequent successful logins. | Credential Access | admin | 50 |
