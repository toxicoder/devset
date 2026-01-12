---
layout: page
title: High Error Rate
permalink: /playbooks/high_error_rate/
---

# Playbook: High Error Rate

## Incident Overview
**Playbook Name:** High Error Rate
**Target Response Time:** < 15 Minutes
**Scenario:** Elevated rate of 5xx errors (Internal Server Errors).

## 1. Symptoms
* Alert: "5xx Rate > 1%".
* Users seeing "Something went wrong" pages.

## 2. Severity Assessment
* **SEV 1:** Error rate > 10%. Critical user flows blocked.
* **SEV 2:** Error rate > 1%. Non-critical flows affected.
* **SEV 3:** Elevated errors on low-traffic endpoints.

## 3. Initial Verification
* Check **Error Dashboard**.
* Identify the specific status code (500, 502, 503, 504).
    * **500:** Application logic crash / unhandled exception.
    * **502/504:** Upstream timeout or connection failure.
    * **503:** Service unavailable / overloaded.

## 4. Investigation
1.  **Logs:** Check application logs (Splunk/ELK) for stack traces.
    * Search for `ERROR` or `Exception`.
2.  **Recent Changes:** Did a deployment just happen?
3.  **Health Checks:** Are pods failing health checks and restarting?

## 5. Mitigation
* **Rollback:** If a recent deployment caused it, rollback immediately.
* **Restart:** Restart unhealthy pods.
* **Circuit Break:** If a dependency is failing, open the circuit breaker to fail fast.

## 6. Resolution
* Fix the bug causing the exception.
* Patch the dependency or configuration.

## 7. Escalation
* If related to core platform, page **Platform Team**.
## Incident Commander Responsibilities
*   **Assess:** Determine the severity and impact.
*   **Coordinate:** Assign roles (Ops Lead, Comms Lead).
*   **Communicate:** Update the status page and stakeholders every 30 minutes.

## Communication Templates
**Internal Update:**
> "We are investigating an issue with High Error Rate. Impact is [Low/High]. Next update in 30 mins."

## Post-Incident Procedure
1.  Ensure all logs and artifacts are preserved.
2.  Schedule a Blameless Post-Mortem within 24 hours.
