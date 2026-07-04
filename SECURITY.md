# Security Policy

## Reporting a Vulnerability

**Do NOT open a public issue for security vulnerabilities.**

Please report security vulnerabilities through
[GitHub Security Advisories](https://github.com/tomada1114/spyglass/security/advisories/new).

Include:

- Description of the vulnerability
- Steps to reproduce
- Affected versions
- Suggested fix (if available)

## Response Timeline

| Action | Timeline |
|---|---|
| Acknowledgment | Within 48 hours |
| Initial assessment | Within 7 days |
| Fix release | Best effort, typically within 30 days |

## Supported Versions

| Version | Supported |
|---|---|
| Latest release | Yes |
| Previous minor | Best effort |

## Supply-Chain Posture

This repository pins every GitHub Action to a full commit SHA, pins CLI tools
in `mise.toml`, runs zizmor and OpenSSF Scorecard, and delays automated
dependency updates with a Dependabot cooldown. Scorecard's Fuzzing and
Packaging checks legitimately read N/A for a macOS GUI app.

## Responsible Disclosure

We follow a coordinated disclosure process. We ask that you:

1. Report the issue privately using the method above
2. Allow reasonable time for a fix before public disclosure
3. Avoid exploiting the vulnerability beyond what is necessary to demonstrate it

We will credit reporters in the release notes unless they prefer to remain
anonymous.
