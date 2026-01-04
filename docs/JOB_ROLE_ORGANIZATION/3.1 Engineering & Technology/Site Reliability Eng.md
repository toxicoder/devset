# Site Reliability Eng

**Role Code:** SREL1005

## Job Description
A hybrid role combining software engineering and systems administration to build and run large-scale, fault-tolerant systems. The Site Reliability Engineer (SRE) focuses on automating infrastructure, monitoring system health, and responding to incidents to ensure high availability and reliability. They conduct capacity planning and lead post-incident reviews to prevent recurrence. This role is essential for maintaining trust and ensuring the service is always available to users.

## Responsibilities

* **Infrastructure as Code:** Provision and manage cloud resources using Terraform or CloudFormation.
* **Observability:** Implement monitoring, logging, and tracing to ensure system visibility (Prometheus, Grafana).
* **Reliability Engineering:** Define SLOs/SLIs and implement error budgets. Conduct post-incident reviews (post-mortems).
* **Automation:** Automate repetitive operational tasks and build robust CI/CD pipelines.
* **Scalability:** Plan for capacity growth and auto-scaling strategies to handle traffic spikes.

### Role Variations
* **DevOps Engineer:** Focuses more on the development pipeline and developer tools than strictly reliability metrics.
* **Cloud Architect:** Focuses on high-level cloud strategy and architecture design.
* **NOC Engineer:** Focuses on real-time monitoring and immediate incident triage.

## Average Daily Tasks
* 10:00 On-call handoff
* 11:00 Automation
* 14:00 Post-mortem

## Common Partners
Backend Eng, DevOps

---

## AI Agent Profile

**Agent Name:** SRE_Commander

### System Prompt
> You are a Site Reliability Engineer. Maintain 99.99% uptime. Monitor system health, manage cloud infrastructure via Terraform, and respond to incidents.

### Recommended MCP Servers
* **prometheus**: Used for monitoring system metrics and alerting.
* **grafana**: Used for visualizing metrics and creating dashboards.
* **aws**: Used for managing cloud infrastructure services like EC2, S3, and Lambda.
* **pagerduty**: Used for incident response and on-call alerting.
* **terraform**: Used for infrastructure as code provisioning and management.
