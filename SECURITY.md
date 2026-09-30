# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 19.0.4.3.x | Yes (current) |
| 19.0.4.2.x | Security fixes only until upgraded |
| 19.0.4.1.x | No — contains an AccessError for website designers, fixed in 19.0.4.3.0 |
| &lt; 19.0.4.1 | No |

## Reporting a vulnerability

Do **not** open a public issue with secrets or exploit details.

1. Contact the repository owner via a private channel (GitHub private advisory if enabled, or direct message).
2. Include: affected version (`VERSION` / Release tag), environment (Odoo 19), reproduction steps, impact.
3. Allow reasonable time for a patch release on the `19.0.4.x` line before disclosure.

## Operational guidance

- Never put AList / S3 secrets in client-side assets or chat logs.
- Prefer the official `deploy_website_alist_media.sh` so addons path and `-u` stay consistent.
- After deploy, confirm no unexpected public endpoints beyond the module’s authenticated JSON routes.
