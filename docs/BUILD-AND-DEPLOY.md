# Build, Test and Deploy

How golden images are built, tested and published, locally and in CI.

## The build graph

[`docker-bake.hcl`](../docker-bake.hcl) is the **only** build definition. Local
scripts, the Makefile and CI all run it, so what you test is what ships.

```
alpine-3-22  alpine-3-23  alpine-3-24 ──┬─▶ nginx, python, aspnet, dotnet
debian-12    debian-13                  └─▶ openjdk ──▶ tomcat, springboot
redhat-9     redhat-10
```

* One target per LTS version, expanded from `configs/lts-versions.env` by a bake
  `matrix`; platform versions come from `configs/platform-lts-versions.env`
  (`scripts/bake-env.sh` feeds both files to bake).
* Platform images consume the hardened Alpine base through a named context
  (`target:alpine-3-24`), so the whole graph builds in one BuildKit session, in
  parallel, with no push/pull round-trip between stages.
* Groups: `default` (quick local set), `bases`, `platforms`, `all`.

### Cache rules (why rebuilds are fast *and* patched)

* **No per-build value reaches a `RUN` step.** Build date, git revision and
  version are applied as bake `labels` (image config only). Previously
  `ARG BUILD_DATE` sat above every `RUN`, and since CI set it to the current
  second, every CI build re-ran every step on every architecture.
* **`PATCH_EPOCH` is the only cache-buster.** CI sets it to the UTC date, so the
  `apk/apt/microdnf upgrade` layers re-run at most once a day. A cached layer
  can't pin stale packages for longer than that.
* Hardening scripts are bind-mounted (`RUN --mount=type=bind`), never copied
  into a layer.

## Local: Docker Desktop

```bash
./scripts/local-build-test.sh                 # all 14 images: lint, build, smoke tests, CIS gate
./scripts/local-build-test.sh --quick         # default Alpine/Debian bases + nginx + python
./scripts/local-build-test.sh --report r.md   # + size/vulnerability table
./scripts/local-build-test.sh --platform linux/amd64   # CI's arch, under emulation
make build-alpine-3.24   make build-tomcat    make plan    make report
```

The pipeline is:

1. **Dockerfile lint**: `trivy config` (CIS Docker build checks).
2. **Build**: one `docker buildx bake --load`.
3. **Smoke tests** (`scripts/smoke-test.sh`), all with every capability dropped:
   non-root uid 10001, no setuid/setgid files, the HEALTHCHECK actually turns
   healthy, nginx serves `/health` with security headers on a read-only rootfs,
   Tomcat answers HTTP with no default webapps, Python bootstraps pip into its
   venv, the JRE and .NET runtimes start.
4. **CIS gate**: `trivy image` (vuln/secret/misconfig, fixable HIGH/CRITICAL
   fails).

Images are tagged `golden-local/<image>:<tag>`; set `REGISTRY=` to change the
prefix.

## CI: `.github/workflows/build.yml`

```
lint ─▶ plan ─▶ build (amd64 ‖ arm64) ─▶ merge ─▶ security-report
                                              └─▶ promote-acr   (when Azure is configured)
```

| Trigger | Builds | Pushes |
|---|---|---|
| pull request (image/script changes) | amd64 | no |
| daily 04:23 UTC | amd64 + arm64 | yes, with `latest` |
| manual dispatch | chosen platforms/scope | optional |

* **build**: each architecture runs on a *native* runner (`ubuntu-24.04` and
  `ubuntu-24.04-arm`, no QEMU). It builds and loads the whole graph, smoke-tests
  it, gates it, and only then pushes by digest with SLSA provenance and an SBOM.
  The push is served from the cache of the build that was tested. The GHA cache
  is scoped per target and architecture.
* **merge**: `docker buildx imagetools create` stitches the per-arch digests
  into multi-arch tags, registry-side.
* **security-report**: Trivy SARIF of every published image goes to the
  Security tab.
* **promote-acr**: copies every published tag to ACR (see below).

Repository variable `ARM64_RUNNER` overrides the arm64 runner label; set it to
`qemu` if your plan has no hosted arm64 runners.

### Tags

| Image | Tags |
|---|---|
| base | `<os>-hardened:<ver>`, `:<ver>-<YYYYMMDD>`, `:<ver>-sha-<git7>`, `:latest` (default version) |
| platform | `<p>-platform:<pver>-alpine<aver>`, `…-<YYYYMMDD>`, `…-sha-<git7>`, `:<pver>`, `:latest` |

e.g. `ghcr.io/robertncl/nginx-platform:1.30-alpine3.24-20261019`. Pin the dated
or sha tag (or the digest) for reproducible deployments; the floating tags move
with the daily patch rebuild.

## Deploying to GitHub

```bash
scripts/deploy/github-setup.sh check     # gh auth, workflow, Actions, variables
scripts/deploy/github-setup.sh run       # dispatch build.yml and follow it
scripts/deploy/github-setup.sh run --no-push --platforms linux/amd64   # dry pipeline
scripts/deploy/github-setup.sh status
```

GHCR needs no secret: the workflow pushes with its own `GITHUB_TOKEN`. New
packages are private; make them public in the package settings if consumers
pull anonymously.

## Deploying to Azure (ACR)

One-time, idempotent setup (needs `az login` with rights to create an app
registration and assign roles):

```bash
scripts/deploy/azure-bootstrap.sh --acr-name <name> --dry-run            # preview
scripts/deploy/azure-bootstrap.sh --acr-name <name> --configure-github   # do it
```

It creates the resource group and the ACR (admin user disabled), an Entra ID
app whose **federated credential** trusts GitHub OIDC tokens for
`repo:<owner>/<repo>:ref:refs/heads/<default-branch>` only, and an **AcrPush**
role assignment scoped to that one registry. It then stores `ACR_NAME`,
`AZURE_CLIENT_ID`, `AZURE_TENANT_ID` and `AZURE_SUBSCRIPTION_ID` as repository
variables. No password, client secret or ACR admin credential exists anywhere.
From then on every publishing run promotes to ACR. Re-promote specific tags with
the **Promote Images to Azure Container Registry** workflow, or by hand:

```bash
az acr login --name <name>
scripts/promote-to-acr.sh --acr <name> --verify ghcr.io/<owner>/nginx-platform:1.30
```

Promotion is a registry-to-registry copy (`imagetools create`), so every
architecture and the attestations arrive intact. The previous pull/tag/push
sync copied only the runner's own architecture.

## Publishing from a workstation

Without CI, for example to seed a registry:

```bash
echo "$CR_PAT" | docker login ghcr.io -u <user> --password-stdin
scripts/publish.sh --registry ghcr.io/<owner> [--acr <name>] [--targets "nginx python"]
```

`publish.sh` builds and CIS-gates each platform first (smoke tests on the
native one), shows the tags, asks for confirmation, then pushes multi-arch
images with provenance and SBOM. This needs Docker Desktop's containerd image
store (the default) or a `docker-container` builder.
