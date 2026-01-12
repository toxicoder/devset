---
layout: page
title: SSO Troubleshooting
permalink: /technical_support/identity_access/sso_troubleshooting/
---

# SSO Troubleshooting

## Overview
This document provides detailed technical support information for **SSO Troubleshooting**. It is intended for end-users and support staff.

## Configuration & Instructions
## Single Sign-On (SSO) Troubleshooting

We use Okta for Single Sign-On to access most internal applications (Slack, Jira, GitHub, etc.).

### Common Issues

#### "400 Bad Request" or Loop
*   **Cause**: Corrupted browser cookies or cache.
*   **Fix**:
    1.  Clear your browser cache and cookies for `*.company.com` and `*.okta.com`.
    2.  Restart your browser.
    3.  Try logging in again.

#### "Access Denied"
*   **Cause**: You may not have the required group membership for the application.
*   **Fix**:
    1.  Check if your teammates have access.
    2.  Request access via the [Software Request](../software/software_request/) process (Access Request in Jira).
    3.  Include the specific error message and app name.

#### "MFA Prompt Not Appearing"
*   **Cause**: Ad blockers or browser extensions.
*   **Fix**:
    1.  Disable ad blockers for the SSO page.
    2.  Try using Incognito/Private mode.

### verifying Browser Compatibility

Ensure you are using the latest version of Chrome, Firefox, or Safari. Internet Explorer is not supported.

## Troubleshooting Guide
1.  **Reproduce:** Try to reproduce the issue consistently.
2.  **Isolate:** Determine if the issue is with the hardware, software, or network.
3.  **Logs:** Check the logs for specific error codes.

## Getting Help
If the issue persists:
1.  Search the Knowledge Base.
2.  Ask in the `#general-support` Slack channel.
3.  Open a Jira ticket.
