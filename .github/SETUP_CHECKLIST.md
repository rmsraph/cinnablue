# Repository Setup Checklist

## Initial Setup

### 1. Rename Template
- [ ] Confirm repository identity is `cinablue` in: Containerfile, Justfile, README.md, artifacthub-repo.yml, custom/ujust/README.md, .github/workflows/clean.yml

### 2. Enable GitHub Actions
- [ ] Settings → Actions → General → Enable workflows
- [ ] Set "Read and write permissions"
- [ ] Run `Build container image` via `workflow_dispatch` and verify it completed successfully
- [ ] Confirm validation workflows are green on latest commit

### 3. First Push
```bash
git add .
git commit -m "feat: initial customization"
git push origin main
```

### 4. Deploy
```bash
sudo bootc switch --transport registry ghcr.io/YOUR_USERNAME/YOUR_REPO:stable
sudo systemctl reboot
```

## Optional: Production Features

### Enable Signing (Recommended)
```bash
cosign generate-key-pair
# Add cosign.key to GitHub Secrets as SIGNING_SECRET
# Uncomment signing in .github/workflows/build.yml
```

