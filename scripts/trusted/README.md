# Trusted post-install scripts

Only `.ps1` files in this directory may be referenced by package `PostInstallScript`.

Inline script content is rejected. Paths must be repo-relative, for example:

```text
scripts/trusted/configure-example.ps1
```

Scripts run after a successful Winget/Chocolatey/VS Code extension install.
