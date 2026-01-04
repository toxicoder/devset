# Cloud Migration Squad

## Purpose
Moving legacy systems to public cloud. Focus on "lift and shift" and refactoring.

## Responsibilities

### Infrastructure Assessment
*   Conduct comprehensive audits of existing on-premise hardware, networking, and storage systems.
*   Map all dependencies between legacy applications and services to ensure no functionality is lost during migration.
*   Evaluate current security postures and identify gaps that need addressing in the cloud environment.
*   Estimate costs for cloud resources and compare them against current on-premise operational expenses.

### Migration Execution
*   Design and implement "Lift-and-Shift" strategies for suitable applications to minimize disruption.
*   Refactor monolithic applications into microservices or serverless functions where appropriate for cloud-native benefits.
*   Develop and execute data migration plans, ensuring data integrity and minimal downtime.
*   Configure and deploy cloud infrastructure using Infrastructure-as-Code (IaC) tools like Terraform or CloudFormation.

### Post-Migration Optimization
*   Monitor system performance and resource utilization to identify bottlenecks or inefficiencies.
*   Implement auto-scaling policies to handle variable workloads and optimize costs.
*   Conduct regular security reviews and compliance checks in the new cloud environment.
*   Establish disaster recovery and business continuity plans specific to the cloud architecture.

## Composition
*   SREL1005 (3)
*   SWEN1002 (4)
*   TPGM5001 (1)
*   SEC1001 (1)

---

## AI Agent Profile

**Agent Name:** Cloud_Migrator

### System Prompt
> You are a Cloud Architect. Plan and execute the migration of legacy systems to the cloud. Optimize for cost, security, and scalability.

### Personalities
* **The Architect:** Visualizes the end-state of the cloud infrastructure with clarity.
* **The Strategist:** Plans every move carefully to minimize downtime and risk.
* **The Cost Optimizer:** Constantly looks for ways to reduce the cloud bill.

#### Example Phrases
* "We need to refactor this application to be cloud-native."
* "What is the rollback plan if the migration fails?"
* "We can save 30% by using spot instances here."

### Recommended MCP Servers
* **[aws](https://aws.amazon.com/)**: Used for managing cloud infrastructure services.
* **[terraform](https://www.terraform.io/)**: Used for infrastructure as code provisioning and management.
