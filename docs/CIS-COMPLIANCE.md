# CIS Compliance

This build platform produces two product families and hardens/verifies each
against the relevant CIS benchmark. The single most important design rule:
**container hardening and VM hardening are separate** and never share scripts.

| Product | Benchmark | Hardening | Verification gate (hard fail) |
|---------|-----------|-----------|-------------------------------|
| Container images | CIS Docker Benchmark **v1.7.0** (§4 image checks) | `scripts/container/harden-*.sh` run during `docker build` | `scripts/lint-dockerfiles.sh` (`trivy config`) + `scripts/cis-verify.sh` (`trivy image`) |
| Linux VM images | CIS Distribution Independent / per-distro Linux Benchmarks | `scripts/vm/harden-*.sh` + OpenSCAP SSG remediation | `scripts/vm/openscap-remediate.sh` (score gate, min 70) inside Packer |
| Windows VM images | CIS Microsoft Windows Server Benchmark | `scripts/vm/harden-windows.ps1` | (manual / Windows SCAP) |

> Why the split matters: the previous platform ran VM-style controls
> (`systemctl`, `ufw`, `iptables`, `sshd`, `auditd`) *inside* `docker build`,
> where there is no init system — so the builds aborted and nothing was actually
> hardened. Those controls now live only in `scripts/vm/`.

## Container images — CIS Docker Benchmark v1.7.0

Each hardened base image (`base-images/<os>/Dockerfile.<ver>`) and platform image
(`platform-images/<name>/Dockerfile`) implements the build-time CIS §4 controls:

| CIS control | How it is met | Where |
|-------------|---------------|-------|
| 4.1 Create a user for the container | non-root `appuser` (uid/gid **10001**); `USER appuser` is the final user | `scripts/container/harden-*.sh`, every Dockerfile |
| 4.2 / 4.5 Use trusted base images | upstream base pinned by tag **and digest** (`FROM alpine:3.20@sha256:…`) | base Dockerfiles |
| 4.3 Do not install unnecessary packages | only `ca-certificates` + init; `--no-install-recommends` / `--no-cache` | base + platform Dockerfiles |
| 4.6 Add HEALTHCHECK | `HEALTHCHECK` in every image | all Dockerfiles |
| 4.7 Do not use update instructions alone | `update`/`upgrade`/`install` combined in one `RUN`, caches purged | base + platform Dockerfiles |
| 4.8 Remove setuid/setgid where possible | `find … -perm -4000/-2000 … chmod -s` (base + `harden-runtime.sh`) | `scripts/container/*` |
| 4.9 Use COPY not ADD | only `COPY` is used | all Dockerfiles |
| 4.10 Do not store secrets | `.dockerignore` excludes `*.env`/keys; `trivy image --scanners secret` gate | `.dockerignore`, `cis-verify.sh` |
| 4.11 Install verified packages only | distro package managers + Microsoft's signed feed; pinned Tomcat w/ SHA-512 | platform Dockerfiles |
| (host hygiene) | system accounts locked, `login.defs` UMASK 027 / SHA512, world-writable bits removed | `scripts/container/harden-*.sh` |

### The container CIS gate

Two Trivy-powered checks; either failing blocks the build/push:

1. **`scripts/lint-dockerfiles.sh`** → `trivy config` lints the Dockerfiles
   against Aqua's Docker checks (AVD-DS-*), covering the CIS build practices:
   non-root final USER (DS-0002), COPY-not-ADD (DS-0005), HEALTHCHECK (DS-0026), etc.
2. **`scripts/cis-verify.sh`** → `trivy image --scanners vuln,secret,misconfig`
   on the built artifact (CVEs, embedded secrets, config issues).

> **No Dockle.** The pipeline intentionally does not use the `goodwithtech/dockle`
> container image (it carried vulnerabilities). Trivy — already trusted and used
> for vulnerability scanning — provides equivalent CIS-DI coverage via its config
> and image scanners, as a static binary or its own minimal image.

Run locally:

```bash
make lint-dockerfiles                                  # Dockerfile CIS checks
make cis-verify IMAGE=ghcr.io/<ns>/alpine-hardened:3.20 # built-image scan
./scripts/local-build-test.sh --all-platforms --with-redhat  # build + verify everything
```

In CI (`.github/workflows/build.yml`) the gate runs **before push**: images are
built single-arch and loaded, verified, and only then built multi-arch and pushed.

## Linux VM images — OpenSCAP SSG

`scripts/vm/openscap-remediate.sh` installs the SCAP Security Guide, applies the
CIS profile with `oscap xccdf eval --remediate`, re-scans, and **fails the Packer
build** if the compliance score is below `MIN_SCORE` (default 70). Supplementary
controls that SSG does not cover are applied first by `scripts/vm/harden-<os>.sh`
(SSH, sysctl, firewall, auditd, kernel module blacklist, password policy).

**Alpine has no official CIS SSG content**, so Alpine VMs are hardened by
`scripts/vm/harden-alpine.sh` only (no OpenSCAP score gate).

## Windows VM images

`scripts/vm/harden-windows.ps1` applies CIS Windows Server controls (password &
lockout policy, complexity, Guest account disabled, firewall default-deny, audit
policy, SMBv1 disabled). The build VM's admin password is supplied via the
`PKR_VAR_admin_password` secret — it is **no longer hardcoded** in the Packer file.
