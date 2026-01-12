---
layout: page
title: Incident Management
permalink: /engineering_standards/incident_management/
---

Incidents are inevitable. How we respond to them defines our reliability and
trust with customers. This document outlines our incident response process.

## Severity Levels (SEV)

We classify incidents based on their impact:

* **SEV 1 (Critical):** System is down or major functionality is broken for all
  users. Data loss or security breach.
  * *Response Time:* Immediate (15 min)
  * *Who to Page:* On-Call, Eng Manager, Director, Execs

* **SEV 2 (Major):** Significant impact. Core functionality broken for a subset
  of users. Performance severely degraded.
  * *Response Time:* Immediate (30 min)
  * *Who to Page:* On-Call, Eng Manager

* **SEV 3 (Minor):** Minor impact. Non-critical functionality broken. Workaround
  available.
  * *Response Time:* Within 24 hours
  * *Who to Page:* On-Call (during business hours)

* **SEV 4 (Trivial):** Cosmetic issues, minor bugs, low impact.
  * *Response Time:* Next Sprint
  * *Who to Page:* File a ticket

## Roles

During a SEV 1 or SEV 2 incident, specific roles are assigned to ensure clear
communication and resolution:

* **Incident Commander (IC):** The leader of the response. Coordinates the team,
  manages communication, and makes high-level decisions. Does *not* debug.
* **Operations Lead:** The primary investigator. Debugs the system, proposes
  fixes, and executes remediation.
* **Communications Lead:** Updates the status page, communicates with
  stakeholders (Support, CS, Execs), and manages the incident channel.

## Process

### 1. Detect & Declare

* Anyone can declare an incident. If you see something, say something.
* Open an incident channel (e.g., `#incident-<id>`) in Slack.
* Determine the initial SEV level.

### 2. Assess & Mitigate

* **Focus on Mitigation:** The primary goal is to restore service, *not* to find
  the root cause. Rollback changes, disable features, or scale up resources.
* **Communicate:** The IC should post regular updates (every 30 mins for SEV 1)
  in the incident channel.

### 3. Resolve

* Once the system is stable, the incident is resolved.
* Ensure monitoring is green.

### 4. Post-Mortem

* For all SEV 1 and SEV 2 incidents, a
  [Post-Mortem](/engineering_standards/post_mortem_guide/) is required within
  48 hours.

## Communication Templates

**Initial Announcement:**

> **Incident Declared:** SEV [Level]
> **Description:** [Brief description of impact]
> **Channel:** #incident-[id]
> **IC:** @[user]

**Update:**

> **Status Update:** [Mitigating / Investigating / Monitoring]
> **Impact:** [Current impact]
> **Next Steps:** [Action items]
