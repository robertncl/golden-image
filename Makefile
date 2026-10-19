# Golden Image Build System Makefile
#
# Every build goes through ONE bake graph (docker-bake.hcl); these targets are
# thin wrappers around the scripts that CI runs too.

-include configs/lts-versions.env
-include configs/platform-lts-versions.env
# The env files quote list values for the shell; make keeps quotes literally.
ALPINE_VERSIONS := $(subst ",,$(ALPINE_VERSIONS))
DEBIAN_VERSIONS := $(subst ",,$(DEBIAN_VERSIONS))
REDHAT_VERSIONS := $(subst ",,$(REDHAT_VERSIONS))

BAKE := docker buildx bake -f docker-bake.hcl
# Feed configs/*.env into bake the same way CI does.
BAKE_ENV := eval "$$(scripts/bake-env.sh --export)" &&

# Destination for `make publish`, e.g. make publish REGISTRY=ghcr.io/robertncl
REGISTRY ?=
ACR ?=
ARGS ?=

.PHONY: help
help:
	@echo "Golden Image Build System"
	@echo "========================="
	@echo ""
	@echo "Local (Docker Desktop):"
	@echo "  test                 - Build ALL images, smoke-test + CIS-gate them (ARGS=... for more flags)"
	@echo "  test-quick           - Same for the default Alpine/Debian bases + nginx + python"
	@echo "  build                - Build the default group (no tests)"
	@echo "  build-all            - Build every LTS base + every platform image (no tests)"
	@echo "  build-bases          - Build every LTS base image"
	@echo "  build-platforms      - Build every platform image"
	@echo "  build-<os>-<ver>     - One base, e.g. build-alpine-3.24, build-debian-13, build-redhat-10"
	@echo "  build-<platform>     - One platform, e.g. build-nginx, build-tomcat"
	@echo "  report               - Size/vulnerability report for all images (needs a prior build)"
	@echo "  plan                 - Show the resolved bake graph"
	@echo ""
	@echo "Gates:"
	@echo "  lint-dockerfiles     - CIS Docker build checks (trivy config)"
	@echo "  cis-verify IMAGE=..  - CIS gate for one built image (trivy image)"
	@echo "  smoke-test IMAGE=..  - Functional smoke tests for one built image"
	@echo ""
	@echo "Deploy:"
	@echo "  publish REGISTRY=ghcr.io/<owner> [ACR=<name>]  - Gate + push multi-arch from this machine"
	@echo "  promote-acr ACR=<name> IMAGES='...'            - Copy published tags to ACR"
	@echo "  azure-bootstrap ACR=<name>                     - One-time ACR + OIDC setup (ARGS=--dry-run)"
	@echo "  github-check                                   - Verify the GitHub repo is wired up"
	@echo "  github-run                                     - Dispatch the CI pipeline and follow it"
	@echo ""
	@echo "Config:"
	@echo "  show-lts-versions / show-platform-versions / validate-lts-config"
	@echo "  To add/remove LTS versions edit configs/lts-versions.env; platform defaults"
	@echo "  live in configs/platform-lts-versions.env."

# ---- local build + test -------------------------------------------------------

.PHONY: test test-quick local-test
test:
	@./scripts/local-build-test.sh $(ARGS)
test-quick:
	@./scripts/local-build-test.sh --quick $(ARGS)
local-test: test

.PHONY: build build-all build-bases build-platforms build-base-images build-platform-images plan
build:
	@$(BAKE_ENV) $(BAKE) --load default
build-all:
	@$(BAKE_ENV) $(BAKE) --load all
build-bases build-base-images:
	@$(BAKE_ENV) $(BAKE) --load bases
build-platforms build-platform-images:
	@$(BAKE_ENV) $(BAKE) --load platforms
plan:
	@$(BAKE_ENV) $(BAKE) --print all

# build-alpine-3.24 -> bake target alpine-3-24
build-alpine-% build-debian-% build-redhat-%:
	@$(BAKE_ENV) $(BAKE) --load $(subst .,-,$(patsubst build-%,%,$@))

PLATFORMS_LIST := nginx python openjdk tomcat springboot aspnet dotnet
$(addprefix build-,$(PLATFORMS_LIST)):
	@$(BAKE_ENV) $(BAKE) --load $(patsubst build-%,%,$@)

.PHONY: report
report:
	@$(BAKE_ENV) ./scripts/image-report.sh $$(./scripts/bake-images.sh all)

# ---- gates --------------------------------------------------------------------

.PHONY: lint-dockerfiles cis-verify smoke-test
lint-dockerfiles:
	@./scripts/lint-dockerfiles.sh
cis-verify:
	@if [ -z "$(IMAGE)" ]; then echo "❌ Please specify IMAGE=<image:tag>"; exit 1; fi
	@./scripts/cis-verify.sh $(IMAGE)
smoke-test:
	@if [ -z "$(IMAGE)" ]; then echo "❌ Please specify IMAGE=<image:tag>"; exit 1; fi
	@./scripts/smoke-test.sh $(IMAGE)

# ---- deploy -------------------------------------------------------------------

.PHONY: publish deploy promote-acr sync-to-acr azure-bootstrap github-check github-run
publish deploy:
	@if [ -z "$(REGISTRY)" ]; then echo "❌ Please specify REGISTRY=ghcr.io/<owner>"; exit 1; fi
	@./scripts/publish.sh --registry $(REGISTRY) $(if $(ACR),--acr $(ACR)) $(ARGS)
promote-acr sync-to-acr:
	@if [ -z "$(ACR)" ] || [ -z "$(IMAGES)" ]; then echo "❌ Please specify ACR=<name> IMAGES='<image:tag> ...'"; exit 1; fi
	@./scripts/promote-to-acr.sh --acr $(ACR) $(IMAGES)
azure-bootstrap:
	@if [ -z "$(ACR)" ]; then echo "❌ Please specify ACR=<registry-name>"; exit 1; fi
	@./scripts/deploy/azure-bootstrap.sh --acr-name $(ACR) $(ARGS)
github-check:
	@./scripts/deploy/github-setup.sh check
github-run:
	@./scripts/deploy/github-setup.sh run $(ARGS)

# ---- config -------------------------------------------------------------------

.PHONY: show-lts-versions
show-lts-versions:
	@echo "📋 Current LTS version configuration:"
	@echo "  Alpine versions: $(ALPINE_VERSIONS)  (default $(DEFAULT_ALPINE_VERSION))"
	@echo "  Debian versions: $(DEBIAN_VERSIONS)  (default $(DEFAULT_DEBIAN_VERSION))"
	@echo "  RedHat versions: $(REDHAT_VERSIONS)  (default $(DEFAULT_REDHAT_VERSION))"

.PHONY: show-platform-versions
show-platform-versions:
	@echo "📋 Platform defaults (built on Alpine $(DEFAULT_ALPINE_VERSION)):"
	@echo "  Nginx $(DEFAULT_NGINX_VERSION), OpenJDK $(DEFAULT_OPENJDK_VERSION), Tomcat $(DEFAULT_TOMCAT_VERSION),"
	@echo "  Python $(DEFAULT_PYTHON_VERSION), Spring Boot $(DEFAULT_SPRINGBOOT_VERSION),"
	@echo "  ASP.NET $(DEFAULT_ASPNET_VERSION), .NET $(DEFAULT_DOTNET_VERSION)"

.PHONY: validate-lts-config
validate-lts-config:
	@echo "🔍 Validating LTS version configuration..."
	@$(BAKE_ENV) for os in alpine debian redhat; do \
		case $$os in alpine) vs="$$ALPINE_VERSIONS";; debian) vs="$$DEBIAN_VERSIONS";; redhat) vs="$$REDHAT_VERSIONS";; esac; \
		for v in $$vs; do \
			[ -f base-images/$$os/Dockerfile.$$v ] || { echo "❌ Missing base-images/$$os/Dockerfile.$$v"; exit 1; }; \
		done; \
	done
	@$(BAKE_ENV) $(BAKE) --print all >/dev/null 2>&1
	@echo "✅ LTS version configuration is valid"

# ---- optional extra scanners --------------------------------------------------

.PHONY: scan-comprehensive scan-trivy scan-prisma scan-prisma-only
scan-comprehensive:
	@./scripts/comprehensive-scan.sh
scan-trivy:
	@./scripts/comprehensive-scan.sh --trivy-only
scan-prisma:
	@./scripts/prisma-scan.sh
scan-prisma-only:
	@./scripts/comprehensive-scan.sh --prisma-only

.PHONY: clean
clean:
	@echo "🧹 Removing locally built golden images and dangling build cache..."
	-@docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^golden-(local|gate-)' | xargs -r docker rmi
	@docker builder prune -f
