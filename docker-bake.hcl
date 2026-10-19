# docker-bake.hcl — the ONE build graph for every golden image, local and CI.
#
# Every base LTS version and every platform image is a target in a single
# BuildKit graph, so independent images build in parallel and shared layers are
# built once. Platform images consume the hardened Alpine base through a named
# context (`target:alpine-<ver>`) and Tomcat/Spring Boot consume the OpenJDK
# target the same way: no push/pull round-trip between stages, and bake orders
# the dependencies itself.
#
# Cache rules that keep rebuilds fast AND patched:
#   * No per-build value (date, git sha) is visible to any RUN step. Build
#     metadata is applied as `labels`, which BuildKit writes into the image
#     config after the build, so it never invalidates a layer.
#   * PATCH_EPOCH is the only cache-busting input. CI sets it to the UTC date,
#     so the `apk/apt/microdnf upgrade` layers re-run once a day; a cached layer
#     can never pin stale packages for longer than that.
#
# Variables come from the environment; scripts/bake-env.sh exports the values
# in configs/*.env. Groups: default (quick local), bases, platforms, all.

variable "REGISTRY" { default = "golden-local" }

variable "ALPINE_VERSIONS" { default = "3.22 3.23 3.24" }
variable "DEBIAN_VERSIONS" { default = "12 13" }
variable "REDHAT_VERSIONS" { default = "9 10" }
variable "DEFAULT_ALPINE_VERSION" { default = "3.24" }
variable "DEFAULT_DEBIAN_VERSION" { default = "13" }
variable "DEFAULT_REDHAT_VERSION" { default = "10" }

variable "DEFAULT_NGINX_VERSION" { default = "1.30" }
variable "DEFAULT_PYTHON_VERSION" { default = "3.14" }
variable "DEFAULT_OPENJDK_VERSION" { default = "25" }
variable "DEFAULT_TOMCAT_VERSION" { default = "11.0" }
variable "DEFAULT_SPRINGBOOT_VERSION" { default = "4.1" }
variable "DEFAULT_ASPNET_VERSION" { default = "10.0" }
variable "DEFAULT_DOTNET_VERSION" { default = "10.0" }

variable "PATCH_EPOCH" { default = "" }
variable "BUILD_DATE" { default = "" }
variable "VCS_REF" { default = "local" }
variable "VERSION" { default = "1.0.0" }
variable "SOURCE_URL" { default = "https://github.com/robertncl/golden-image" }

# Publishing knobs (CI). TAG_SUFFIXES is a comma list appended as `<ver>-<s>`.
variable "TAG_SUFFIXES" { default = "" }
variable "PUBLISH_LATEST" {
  type    = bool
  default = false
}
variable "PUSH_BY_DIGEST" {
  type    = bool
  default = false
}
variable "PLATFORMS" { default = "" }          # empty = the builder's native platform
variable "CACHE_BACKEND" { default = "" }      # "gha" in CI; local builds use the builder cache
variable "CACHE_SCOPE_SUFFIX" { default = "" } # per-arch runners must not share a cache scope
variable "CACHE_TO" {                          # false: read the cache but don't re-export it
  type    = bool
  default = true
}
variable "ATTEST" { # SLSA provenance + SBOM on registry pushes
  type    = bool
  default = false
}

function "slug" {
  params = [v]
  result = replace(v, ".", "-")
}

# Tags for one image: the fully-qualified <tag>, <tag>-<suffix> for each
# TAG_SUFFIXES entry (immutable date/sha pins), any short aliases, and `latest`
# for the default flavour when publishing. When pushing by digest only the
# repository name is given (CI merges the per-arch digests into tagged
# manifest lists afterwards).
function "image_tags" {
  params = [repo, tag, aliases, is_default]
  result = PUSH_BY_DIGEST ? ["${REGISTRY}/${repo}"] : concat(
    ["${REGISTRY}/${repo}:${tag}"],
    [for s in compact(split(",", TAG_SUFFIXES)) : "${REGISTRY}/${repo}:${tag}-${s}"],
    [for a in aliases : "${REGISTRY}/${repo}:${a}"],
    is_default && PUBLISH_LATEST ? ["${REGISTRY}/${repo}:latest"] : []
  )
}

function "cache_from" {
  params = [scope]
  result = CACHE_BACKEND == "" ? [] : ["type=${CACHE_BACKEND},scope=${scope}${CACHE_SCOPE_SUFFIX}"]
}

function "cache_to" {
  params = [scope]
  result = CACHE_BACKEND == "" || !CACHE_TO ? [] : ["type=${CACHE_BACKEND},mode=max,scope=${scope}${CACHE_SCOPE_SUFFIX}"]
}

group "default" {
  targets = [
    "alpine-${slug(DEFAULT_ALPINE_VERSION)}",
    "debian-${slug(DEFAULT_DEBIAN_VERSION)}",
    "nginx",
    "python",
  ]
}

group "bases" {
  targets = ["alpine", "debian", "redhat"]
}

group "platforms" {
  targets = ["nginx", "python", "openjdk", "tomcat", "springboot", "aspnet", "dotnet"]
}

group "all" {
  targets = ["bases", "platforms"]
}

target "_common" {
  context   = "."
  platforms = PLATFORMS == "" ? [] : split(",", PLATFORMS)
  args      = { PATCH_EPOCH = PATCH_EPOCH }
  labels = {
    "org.opencontainers.image.created"  = BUILD_DATE
    "org.opencontainers.image.revision" = VCS_REF
    "org.opencontainers.image.version"  = VERSION
    "org.opencontainers.image.source"   = SOURCE_URL
  }
  # Registry pushes carry SLSA provenance + an SBOM; local --load builds skip
  # them (they only slow the inner loop down).
  attest = ATTEST ? ["type=provenance,mode=max", "type=sbom"] : []
  output = PUSH_BY_DIGEST ? ["type=image,push-by-digest=true,name-canonical=true,push=true"] : []
}

# ---- base images: one target per LTS version ---------------------------------

target "alpine" {
  name       = "alpine-${slug(v)}"
  matrix     = { v = split(" ", ALPINE_VERSIONS) }
  inherits   = ["_common"]
  dockerfile = "base-images/alpine/Dockerfile.${v}"
  tags       = image_tags("alpine-hardened", v, [], v == DEFAULT_ALPINE_VERSION)
  cache-from = cache_from("alpine-${v}")
  cache-to   = cache_to("alpine-${v}")
}

target "debian" {
  name       = "debian-${slug(v)}"
  matrix     = { v = split(" ", DEBIAN_VERSIONS) }
  inherits   = ["_common"]
  dockerfile = "base-images/debian/Dockerfile.${v}"
  tags       = image_tags("debian-hardened", v, [], v == DEFAULT_DEBIAN_VERSION)
  cache-from = cache_from("debian-${v}")
  cache-to   = cache_to("debian-${v}")
}

target "redhat" {
  name       = "redhat-${slug(v)}"
  matrix     = { v = split(" ", REDHAT_VERSIONS) }
  inherits   = ["_common"]
  dockerfile = "base-images/redhat/Dockerfile.${v}"
  tags       = image_tags("redhat-hardened", v, [], v == DEFAULT_REDHAT_VERSION)
  cache-from = cache_from("redhat-${v}")
  cache-to   = cache_to("redhat-${v}")
}

# ---- platform images (on the default hardened Alpine base) -------------------
# Tagged <platform-ver>-alpine<alpine-ver> and <platform-ver>.

target "_platform" {
  inherits = ["_common"]
  contexts = { golden-base = "target:alpine-${slug(DEFAULT_ALPINE_VERSION)}" }
}

function "platform_tags" {
  params = [repo, ver]
  result = image_tags(repo, "${ver}-alpine${DEFAULT_ALPINE_VERSION}", [ver], true)
}

target "nginx" {
  inherits   = ["_platform"]
  dockerfile = "platform-images/nginx/Dockerfile"
  args       = { BASE_IMAGE = "golden-base", NGINX_VERSION = DEFAULT_NGINX_VERSION }
  tags       = platform_tags("nginx-platform", DEFAULT_NGINX_VERSION)
  cache-from = cache_from("nginx")
  cache-to   = cache_to("nginx")
}

target "python" {
  inherits   = ["_platform"]
  dockerfile = "platform-images/python/Dockerfile"
  args       = { BASE_IMAGE = "golden-base", PYTHON_VERSION = DEFAULT_PYTHON_VERSION }
  tags       = platform_tags("python-platform", DEFAULT_PYTHON_VERSION)
  cache-from = cache_from("python")
  cache-to   = cache_to("python")
}

target "openjdk" {
  inherits   = ["_platform"]
  dockerfile = "platform-images/openjdk/Dockerfile"
  args       = { BASE_IMAGE = "golden-base", OPENJDK_VERSION = DEFAULT_OPENJDK_VERSION }
  tags       = platform_tags("openjdk-platform", DEFAULT_OPENJDK_VERSION)
  cache-from = cache_from("openjdk")
  cache-to   = cache_to("openjdk")
}

target "aspnet" {
  inherits   = ["_platform"]
  dockerfile = "platform-images/aspnet/Dockerfile"
  args       = { BASE_IMAGE = "golden-base", ASPNET_VERSION = DEFAULT_ASPNET_VERSION }
  tags       = platform_tags("aspnet-platform", DEFAULT_ASPNET_VERSION)
  cache-from = cache_from("aspnet")
  cache-to   = cache_to("aspnet")
}

target "dotnet" {
  inherits   = ["_platform"]
  dockerfile = "platform-images/dotnet/Dockerfile"
  args       = { BASE_IMAGE = "golden-base", DOTNET_VERSION = DEFAULT_DOTNET_VERSION }
  tags       = platform_tags("dotnet-platform", DEFAULT_DOTNET_VERSION)
  cache-from = cache_from("dotnet")
  cache-to   = cache_to("dotnet")
}

# JVM-derived platforms build on the openjdk target, not the raw base.

target "tomcat" {
  inherits   = ["_common"]
  dockerfile = "platform-images/tomcat/Dockerfile"
  contexts   = { golden-jdk = "target:openjdk" }
  args       = { BASE_IMAGE = "golden-jdk" }
  tags       = platform_tags("tomcat-platform", DEFAULT_TOMCAT_VERSION)
  cache-from = cache_from("tomcat")
  cache-to   = cache_to("tomcat")
}

target "springboot" {
  inherits   = ["_common"]
  dockerfile = "platform-images/springboot/Dockerfile"
  contexts   = { golden-jdk = "target:openjdk" }
  args       = { BASE_IMAGE = "golden-jdk", SPRINGBOOT_VERSION = DEFAULT_SPRINGBOOT_VERSION }
  tags       = platform_tags("springboot-platform", DEFAULT_SPRINGBOOT_VERSION)
  cache-from = cache_from("springboot")
  cache-to   = cache_to("springboot")
}
