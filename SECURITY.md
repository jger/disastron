# Security

## Reporting

If you find a security vulnerability in Disastron, **do not post exploit details in public issue trackers or forums**.

Contact the **project maintainers privately** with enough detail to reproduce the issue. When this project is hosted on a git forge, prefer that host's private vulnerability reporting if available.

## Secrets and CI

- Never commit Hugging Face tokens, GitHub personal access tokens, keystores, or `key.properties`.
- The release workflow uses the `GH_TOKEN` repository secret; keep it scoped and rotate it if you suspect exposure.

## History scan (maintenance checklist)

Before the repository was made public, history was searched for common leak patterns (`ghp_`, `xoxb-`, PEM private key headers, and Hugging Face token-shaped `hf_…` strings). No matches indicating committed credentials were found. Substring searches for `hf_` can still surface **benign** code (for example `huggingface` in import paths); use a token-shaped regex if you repeat the check.

To re-run locally:

```bash
git log -p -S 'ghp_' --all
git log -p -S 'xoxb-' --all
git log -p -S 'BEGIN RSA PRIVATE' --all
git log -p --all -G 'hf_[A-Za-z0-9]{20,}'
```

If anything sensitive ever landed in git history, **rotate the credential** and consider history rewriting with maintainer agreement; force-pushing `main` affects all clones.
