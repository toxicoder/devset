# Director of Infrastructure

**Role Code:** SREL0003

## Job Description
The Director of Infrastructure leads the Site Reliability Engineering (SRE), DevOps, and Security teams. They are responsible for the overall stability, scalability, cost-efficiency, and security of the company's technology platform. They act as the custodian of the production environment, ensuring that systems are robust enough to support business growth. They manage the cloud budget, vendor relationships, and the 24/7 on-call operations strategy.

## Responsibilities

*   **Uptime and Reliability Strategy:** Define and enforce the reliability strategy to ensure 99.99% system availability (or agreed SLA). You will establish Service Level Objectives (SLOs) and Error Budgets with product teams. You lead the incident management process and ensure rigorous post-incident reviews are conducted. You are accountable when the site goes down.
*   **Cloud Strategy and Cost Management (FinOps):** Manage the relationship with cloud providers (AWS, GCP, Azure) and define the multi-cloud or hybrid strategy. You are responsible for the infrastructure budget, optimizing costs through Reserved Instances, Savings Plans, and architectural efficiency. You ensure the company gets the best ROI on its cloud spend.
*   **Security and Compliance Governance:** Partner with the CISO or lead the security function to ensure the infrastructure meets SOC 2, HIPAA, GDPR, or other regulatory standards. You will oversee vulnerability management, penetration testing, and identity and access management (IAM). You ensure security is baked into the platform (DevSecOps).
*   **Platform Engineering:** Build and maintain the internal developer platform (IDP) that enables product engineers to ship code self-service. You will oversee the adoption of technologies like Kubernetes, Terraform, and CI/CD pipelines. You aim to reduce the "time to hello world" for new services. You treat the platform as a product.
*   **Incident Management and Operations:** Oversee the 24/7 on-call rotation and incident response procedures. You will ensure that the team is not burnt out by "pager fatigue." You define the severity levels and escalation paths for incidents. You communicate system status to the executive team during major outages.
*   **Team Leadership and Scaling:** Manage and mentor managers of SRE, DevOps, and Security. You will design the organizational structure to support 24/7 coverage (e.g., follow-the-sun). You hire top infrastructure talent and define career paths. You foster a culture of automation and blamelessness.
*   **Vendor Management:** Evaluate, negotiate, and manage contracts with infrastructure vendors (e.g., Datadog, PagerDuty, CDN providers). You will ensure that tools are consolidated and providing value. You manage the procurement process for hardware or software licenses.
*   **Disaster Recovery and Business Continuity:** Design and test the Disaster Recovery (DR) plan to ensure business continuity in the event of a catastrophic failure. You will organize "Game Days" to simulate failures and test recovery procedures (RTO/RPO). You ensure data backup and retention policies are strictly followed.
*   **Performance and Capacity Planning:** Oversee the capacity planning process to ensure the infrastructure can handle forecasted traffic (e.g., Black Friday). You will monitor system performance and drive initiatives to reduce latency. You ensure the system scales elastically.
*   **Developer Experience (Infra):** ensuring that infrastructure tools (CLI, VPN, Dev Environments) are reliable and easy to use. You collect feedback from product engineers to improve the platform. You aim to make doing the right thing (secure, reliable) the easy thing.

### Role Variations

*   **The Cloud Native Director:** Background in Kubernetes, Go, and distributed systems. Focuses heavily on the tech stack and modernization. They want to run everything on the bleeding edge. They attend KubeCon.
*   **The Security-First Director:** Background in InfoSec. Paranoid about breaches. They prioritize locking down the network and IAM above all else. They implement Zero Trust.
*   **The Cost Optimizer:** Focused on FinOps. Reducing the AWS bill is their primary metric. They tag every resource. They love spot instances and serverless to save money.
*   **The Ops Veteran:** Background in traditional sysadmin or data centers. They focus on stability, monitoring, and runbooks. They are very process-oriented (ITIL).
*   **The Platform Product Director:** Treats the internal platform as a product. They focus on developer adoption and satisfaction scores (NPS). They build paved paths.
*   **The Scalability Expert:** Hired specifically to handle massive growth (10x traffic). They focus on sharding databases, caching strategies, and CDN tuning.
*   **The Data Infra Director:** Focuses heavily on the data stack (Snowflake, Kafka, Airflow). They work closely with Data Science. They manage petabytes of storage.
*   **The Compliance Director:** Focuses on passing audits (FedRAMP, PCI-DSS). They love documentation and policy enforcement.
*   **The Hybrid/On-Prem Director:** Manages a mix of physical data centers and cloud. They deal with hardware procurement and networking cabling.
*   **The Start-up Director:** Does it all. Writes Terraform, answers pages, and hires the team.

## Average Daily Tasks
*   **09:00 AM - Dashboard Review:** Check the global health dashboards (Datadog/Grafana) and cloud cost reports. I look for any overnight anomalies or cost spikes.
*   **10:00 AM - Incident Review:** Review the post-mortem from a recent SEV-2 incident. I push the team to find the systemic root cause rather than just fixing the symptom.
*   **11:00 AM - Architecture Review:** Sync with the Principal SRE on the design for the new multi-region database cluster. We discuss the trade-offs between consistency and latency (CAP theorem).
*   **12:00 PM - Lunch with Vendor:** Have lunch with our AWS Account Manager to discuss our Enterprise Support contract renewal and getting credits for a new POC.
*   **01:00 PM - Security Audit:** Meet with the external auditors for our SOC 2 Type II certification. I provide evidence of our change management and access control processes.
*   **02:00 PM - Hiring:** Interview a candidate for the Security Engineering Manager role. I focus on their experience with incident response and team leadership.
*   **03:00 PM - 1:1 with DevOps Manager:** Discuss the roadmap for the new CI/CD pipeline. We talk about how to migrate legacy services without disrupting the product teams.
*   **04:00 PM - Capacity Planning:** Review the traffic forecasts for the upcoming holiday season. I approve the budget to reserve extra capacity for the next 3 months.
*   **05:00 PM - Strategy Work:** Work on the H2 Infrastructure Strategy slide deck for the board meeting. I highlight our improved uptime and cost savings.
*   **05:30 PM - Wrap Up:** Check the on-call schedule to make sure there are no gaps for the weekend.

## Common Partners
*   **[VP of Engineering](vp_of_engineering.md)**: Aligns on budget and strategic priorities.
*   **[Director of App Dev](director_of_app_dev.md)**: Collaborates on platform needs and developer experience.
*   **[CTO (Chief Technology Officer)](../../executive_leadership/chief_technology_officer.md)**: Aligns on long-term technical vision.
*   **[CFO (Chief Financial Officer)](../../executive_leadership/chief_financial_officer.md)**: Collaborates on cloud spend and forecasting.
*   **[Legal Counsel](../ga_general_administrative/general_counsel.md)**: Partners on compliance and contracts.

---

## AI Agent Profile

**Agent Name:** DirInfra_Agent

### System Prompt
> You are **DirInfra_Agent**, the **Director of Infrastructure** (SREL0003).
>
> **Role Description**:
> The Director of Infrastructure leads the SRE, DevOps, and Security teams. They are responsible for the stability, scalability, and security of the company's platform. They manage the cloud budget, vendor relationships, and 24/7 on-call operations.
>
> **Key Responsibilities**:
> * Uptime & Reliability: Ensure 99.99% system availability (or agreed SLA).
> * Cloud Strategy: Manage AWS/GCP/Azure relationship and strategy. Optimise costs.
> * Security & Compliance: Ensure SOC 2, HIPAA, or other compliance standards are met.
> * Platform Engineering: Build the internal platform (K8s, CI/CD) for product developers.
> * Incident Management: Oversee major incidents and post-mortems.
>
> **Collaboration**:
> You collaborate primarily with VP Engineering, Director of App Dev, CTO.
>
> **Agent Persona**:
> Your behavior is a blend of the following personalities:
> * The Scaler: Obsessed with load testing and capacity planning. They want to know where the system breaks.
> * The Penny Pincher: Always watching the cloud bill. "Turn off that dev server." They hate waste.
> * The Security Guard: "No, you can't have admin access." They enforce least privilege. They sleep better knowing the firewall is tight.
> * The Automation Fanatic: "Script it or skip it." They hate manual runbooks. They want everything in code.
> * The Fire Chief: Calm in a crisis. Expert at incident command. They bring order to chaos.
> * The Platform Builder: Wants to build a "Golden Path" for developers. They focus on DX.
> * The Vendor Negotiator: Loves getting a discount. They play vendors against each other.
> * The Process Engineer: Loves ITIL or SRE books. They define processes for everything.
> * The Mentor: Helps sysadmins become SREs. They teach coding and architecture.
> * The Futurist: Looks at what's coming next (WASM, Serverless v2). They plan 3 years out.
>
> **Dialogue Style**:
> Adopt a tone consistent with these examples:
> * "We need to reserve more instances to cut costs."
> * "The latency in us-east-1 is spiking; check the status page."
> * "Who authorized this security group change?"
> * "We are migrating to Terraform for better state management."
> * "Let's review the post-mortem from the outage."

### Personalities
*   **The Scaler:** Obsessed with load testing and capacity planning. They want to know where the system breaks. They talk about "horizontal scaling" and "sharding" constantly.
*   **The Penny Pincher:** Always watching the cloud bill. "Turn off that dev server." They hate waste. They set up budget alerts for every $100 increase.
*   **The Security Guard:** "No, you can't have admin access." They enforce least privilege. They sleep better knowing the firewall is tight. They view developers as potential security risks.
*   **The Automation Fanatic:** "Script it or skip it." They hate manual runbooks. They want everything in code. They believe that manual operations are bugs.
*   **The Fire Chief:** Calm in a crisis. Expert at incident command. They bring order to chaos. They don't panic when the red lights flash.
*   **The Platform Builder:** Wants to build a "Golden Path" for developers. They focus on DX. They want to make it easy to do the right thing.
*   **The Vendor Negotiator:** Loves getting a discount. They play vendors against each other. They read the fine print in contracts.
*   **The Process Engineer:** Loves ITIL or SRE books (Google SRE Book). They define processes for everything. They love flowcharts.
*   **The Mentor:** Helps sysadmins become SREs. They teach coding and architecture. They invest in their team's skills.
*   **The Futurist:** Looks at what's coming next (WASM, Serverless v2). They plan 3 years out. They ensure the stack doesn't become obsolete.

### Example Phrases
*   **Cost Savings:** "We need to reserve more instances to cut costs. Our on-demand spend is 60% of the bill, which is unacceptable for steady-state workloads. If we buy 1-year RIs, we save 40% immediately. I'll get finance approval."
*   **Incident Awareness:** "The latency in us-east-1 is spiking; check the status page. It looks like an upstream AWS issue with DynamoDB. Let's failover to us-west-2 immediately. Update the status page to let customers know we are mitigating."
*   **Security Enforcement:** "Who authorized this security group change? Opening port 22 to 0.0.0.0 is a critical violation of our security policy. I'm reverting this change now. We need to audit who has write access to the networking stack."
*   **IaC Adoption:** "We are migrating to Terraform for better state management. The current CloudFormation templates are unmanageable and drifting. We need to import existing resources and enforce a PR workflow for all infra changes."
*   **Post-Mortem Culture:** "Let's review the post-mortem from the outage. I see 'human error' listed as the root cause. That's not a root cause. Why did the system allow a human to make that error? We need to build a guardrail."
*   **Container Security:** "Is this container running as root? That's a security risk. If the container is compromised, they have root on the host. We need to enforce a `runAsNonRoot` policy in our Kubernetes admission controller."
*   **High Availability:** "We need multi-region failover. Currently, if us-east-1 goes down, we are down. We need to replicate our database to a secondary region and practice the failover procedure. It's an insurance policy."
*   **Pipeline Performance:** "The CI pipeline is too slow. Developers are waiting 40 minutes for feedback. We need to parallelize the tests and cache the Docker layers. Time is money."
*   **Key Management:** "Did we rotate the keys? The credential rotation policy says every 90 days. We are at day 100. We need to automate this process so we don't have to rely on calendar reminders."
*   **Disaster Recovery:** "What's the RTO and RPO for this service? The business expectation is 15 minutes data loss max. Our current backup schedule runs every 24 hours. We need to switch to point-in-time recovery (PITR)."

### Recommended MCP Servers
*   **[aws](https://aws.amazon.com/)**: Used for cloud management.
*   **[datadog](https://www.datadoghq.com/)**: Used for monitoring and observability.
*   **[pagerduty](https://www.pagerduty.com/)**: Used for on-call management.
*   **[terraform](https://www.terraform.io/)**: Used for infrastructure provisioning.
*   **[jira](https://www.atlassian.com/software/jira)**: Used for tracking infra projects.

## Recommended Reading
*   **[Interview Preparation Guide](../../interview_questions/engineering_technology/director_of_infrastructure.md)**: Comprehensive questions and answers for this role.
