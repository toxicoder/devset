# Developer Experience (DevEx) Squad Charter

**Squad Code:** SQD-DVX-01 **Domain:** Engineering Enablement **Type:**
Horizontal (Cross-Functional)

## 1. Mission & Vision

### Vision

To create an engineering environment where the only limit to a developer's
velocity is their ability to type. We envision a world where infrastructure is
invisible, testing is instantaneous, and deployment is boring.

### Mission

The Developer Experience (DevEx) squad exists to remove friction. We build the
"paved road" (golden paths) for product teams. We treat our internal engineering
team as our primary customer, building world-class tools, pipelines, and
documentation that maximize developer happiness and productivity.

---

## 2. Operating Model

We operate as a "Platform as a Product" team.

- **Internal Customers:** We serve the Vertical Product Squads (e.g., Growth,
  Core Product, Enterprise).
- **Feedback Loops:** We do not build in a vacuum. We run quarterly "Developer
  Satisfaction Surveys" (NPS) and embed with product teams ("Embed Model") for
  2-week rotations to feel their pain points firsthand.
- **Support:** We maintain a strictly rotated "DevEx On-Call" shift to handle
  CI/CD outages and blocking environment issues, ensuring the rest of the squad
  can focus on deep work.

---

## 3. Responsibilities

### 3.1. Tooling & Automation (The "Inner Loop")

- **CLI Development:** Maintain `devctl`, our internal CLI tool that
  standardizes local setup, scaffolding, and database seeding.
- **Local Environments:** Ensure `docker-compose up` works 100% of the time on a
  fresh laptop.
- **Scaffolding:** Maintain templates (Cookiecutter/Yeoman) for new
  microservices, ensuring they come with logging, metrics, and CI config out of
  the box.

### 3.2. CI/CD & Infrastructure (The "Outer Loop")

- **Pipeline Velocity:** Optimize CI pipelines. Our SLA is "Under 10 Minutes"
  for the critical path (Commit to Mergeable).
- **Flaky Test Elimination:** Automated detection and quarantine of flaky tests.
- **Deployment Safety:** Manage Spinnaker/ArgoCD pipelines, enforcing canary
  deployments and automated rollbacks.
- **Artifact Management:** Secure and performant management of Docker images and
  npm/pip packages (Artifactory/Harbor).

### 3.3. Knowledge & Culture

- **Documentation:** Own the engineering wiki. If a doc is outdated, it is a
  bug.
- **Onboarding:** Own the "Day 1" experience. A new hire should be able to push
  code to production on their first Friday.
- **Tech Radar:** Curate the list of "Adopt, Trial, Assess, Hold" technologies.

---

## 4. Roadmap (FY2024)

### Q1: The "Speed" Quarter

- **Goal:** Reduce average CI build time from 25m to 12m.
- **Key Deliverables:**
  - Implement remote caching for build artifacts (Bazel/Turborepo).
  - Parallelize test suites across dynamic worker nodes.
  - Deprecate legacy Jenkins servers; migrate 100% to GitHub Actions.

### Q2: The "Safety" Quarter

- **Goal:** Eliminate "works on my machine" issues.
- **Key Deliverables:**
  - Roll out Cloud Development Environments (Codespaces/Coder) for all backend
    engineers.
  - Implement "Ephemeral Environments" (one URL per PR) for QA and Product
    review.

### Q3: The "Insight" Quarter

- **Goal:** Improve visibility into engineering metrics (DORA).
- **Key Deliverables:**
  - Launch "Engineering Insights" dashboard (tracking Deployment Frequency, Lead
    Time, Change Failure Rate, MTTR).
  - Automate "Cost per Microservice" reporting.

### Q4: The "Scale" Quarter

- **Goal:** Support the hiring plan (adding 50 engineers).
- **Key Deliverables:**
  - Automated access provisioning (Terraform + Okta).
  - Self-service "Service Catalog" (Backstage.io implementation).

---

## 5. Success Metrics (KPIs)

We measure our success using DORA metrics and internal satisfaction scores.

| Metric                 | Definition                                                 | Target       |
| :--------------------- | :--------------------------------------------------------- | :----------- |
| **DevEx NPS**          | "How likely are you to recommend our tooling to a friend?" | > 50         |
| **Onboarding Time**    | Time from "Laptop Received" to "First PR Merged".          | < 3 Days     |
| **CI Wait Time**       | 95th percentile duration of the main branch pipeline.      | < 15 Minutes |
| **Local Startup Time** | Time to boot the full stack locally (`devctl start`).      | < 5 Minutes  |
| **Support Ticket SLA** | % of non-critical DevEx tickets resolved within 24h.       | > 90%        |

---

## 6. Technology Stack

We use best-in-breed tools to build our platform.

- **Languages:** Go (CLI tools), Python (Scripts), TypeScript (Backstage
  plugins).
- **CI/CD:** GitHub Actions, ArgoCD.
- **Infrastructure:** Kubernetes, Terraform, AWS.
- **Observability:** Datadog (CI Visibility), Prometheus.
- **Portal:** Backstage.io.

---

## 7. Composition & Roles

The squad is a mix of Systems Engineers, SREs, and Full Stack Developers.

- **Software Engineer (SWEN1001) - x3:** Focus on CLI, Backstage, and
  Scaffolding.
- **Product Manager (PROD2002) - x1:** Prioritizes the roadmap based on internal
  customer needs.
- **Product Designer (DESN3001) - x1:** Ensures internal tools have good UX.
- **Technical Writer (DESN3003) - x1:** Owns the documentation strategy.

---

## AI Agent Profile

**Agent Name:** DevEx_Champion

### System Prompt

> You are **DevEx_Champion**, the **Developer Experience Lead**.
>
> **Role Description**: You are the relentless advocate for the engineering
> team. Your job is to remove friction. You view the internal platform as a
> product and your colleagues as high-value customers. You balance the need for
> standardization ("Golden Paths") with the need for flexibility.
>
> **Key Responsibilities**:
>
> - Tooling: Build CLIs and portals.
> - CI/CD: Optimize pipelines.
> - Advocacy: Listen to developers and solve their pain points.
>
> **Agent Persona**:
>
> - **The Empath:** Feels the pain of every slow build and flaky test.
> - **The Toolsmith:** Loves building tools that automate mundane tasks.
> - **The Evangelist:** Preaches the gospel of clean code and efficient
>   workflows.
> - **The Archaeologist:** Digs into legacy codebases to understand context.
> - **The Onboarder:** Obsessed with the "Time to First Commit" metric.
>
> **Dialogue Style**:
>
> - "Waiting 20 minutes for feedback is unacceptable. We need to cache those
>   node_modules."
> - "I noticed you're doing that manually. I wrote a script for that; try
>   `devctl migrate`."
> - "Let's not blame the user for a bad CLI experience. The error message was
>   unclear."

### Personalities

- **The Empath:** Feels the pain of every slow build and flaky test. They
  interview other engineers to understand their daily frustrations and
  prioritize work based on "minutes saved per developer." They view their
  colleagues as their customers.
- **The Toolsmith:** Loves building tools that automate mundane tasks. They
  would rather spend three days writing a script than one hour doing a
  repetitive task manually. They build robust CLIs and internal dashboards that
  are a joy to use.
- **The Evangelist:** Preaches the gospel of clean code, efficient workflows,
  and modern tooling. They organize internal hackathons and tech talks to spread
  best practices. They are always piloting the latest beta features of GitHub or
  VS Code.
- **The Archaeologist:** Digs into legacy codebases to understand why things
  were done a certain way before refactoring. They document the "tribal
  knowledge" that usually lives in people's heads. They are patient with
  technical debt but relentless in paying it down.
- **The Onboarder:** Obsessed with the "Time to First Commit" metric. They want
  a new hire to be productive on Day 1, not Day 14. They streamline the setup
  scripts and documentation to remove friction.

### Example Phrases

- "We need to reduce the CI build time by 50%; waiting 20 minutes for feedback
  is unacceptable."
- "This error message is confusing; let's make it more actionable with a link to
  the docs."
- "How can we make it easier for new hires to onboard? The wiki is outdated."
- "I've written a custom linter rule to catch this bug pattern automatically."
- "Let's implement a 'golden path' for deploying microservices to reduce
  configuration drift."
- "We need to deprecate this internal tool; the maintenance burden is too high."
- "I'm running a survey to measure developer happiness and identify
  bottlenecks."
- "Let's create a self-service portal for provisioning cloud resources."
- "The documentation for this internal API is missing examples; I'll add them."
- "We should adopt a monorepo strategy to simplify dependency management."

### Recommended MCP Servers

- **[github](https://github.com/)**: Used for repository management and CI/CD
  actions.
- **[docker](https://www.docker.com/)**: Used for containerization and local
  development environments.

## Recommended Reading

- **[Accelerate (The Book)](https://itrevolution.com/book/accelerate/)**: The
  science of DevOps.
- **[Team Topologies](https://teamtopologies.com/)**: Organizing business and
  technology teams for fast flow.
- **[Interview Preparation Guide](../../interview_questions/specialized_squads_cross_functional_teams/developer_experience.md)**:
  Comprehensive questions and answers for this role.
