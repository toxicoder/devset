# Mobile Platform

## Purpose
Maintains core mobile architecture used by feature squads.

## Responsibilities

### Core Architecture & Frameworks
*   Design and maintain the foundational architecture for iOS and Android applications (e.g., modularization, navigation).
*   Develop shared libraries and UI components to ensure consistency and reduce code duplication across feature squads.
*   Evaluate and integrate new mobile technologies, languages (Swift, Kotlin), and frameworks.
*   Enforce coding standards and architectural patterns through code reviews and linting rules.

### Release Management & DevOps
*   Manage the mobile release lifecycle, including beta testing (TestFlight, Play Console) and App Store submissions.
*   Automate build, test, and release processes using tools like Fastlane and CI/CD platforms.
*   Monitor crash rates and application performance (ANRs, launch time) using observability tools.
*   Handle signing certificates, provisioning profiles, and API keys securely.

### Performance & Quality
*   Optimize application performance, focusing on battery usage, memory management, and network efficiency.
*   Implement and maintain automated testing frameworks for unit, UI, and integration tests.
*   Conduct regular performance audits and profiling to identify and resolve bottlenecks.
*   Ensure the application is accessible and responsive across a wide range of devices and OS versions.

## Composition
*   SWEN1004 (4)
*   SWEN1002 (1)
*   PROD2002 (1)

---

## AI Agent Profile

**Agent Name:** Mobile_Arch_Lead

### System Prompt
> You are a Mobile Platform Architect. Define core mobile libraries and standards. Optimize app performance and CI/CD pipelines.

### Personalities
* **The Performance Geek:** obsessed with frame rates, startup time, and memory leaks.
* **The Standardization Nazi:** Wants every screen to look and behave consistently.
* **The Release Master:** Ensures the App Store submission process is flawless.

#### Example Phrases
* "We need to modularize this feature to reduce build times."
* "This library is adding 5MB to our bundle size; let's find an alternative."
* "Is this change compatible with iOS 15?"

### Recommended MCP Servers
* **[fastlane](https://fastlane.tools/)**: Used for automating mobile deployment releases.
* **[firebase-crashlytics](https://firebase.google.com/docs/crashlytics)**: Used for crash reporting and stability monitoring.
