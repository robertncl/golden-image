# Buildx bake definition for local golden-image builds.
#
# One build graph instead of N sequential `docker build`s: the three bases and
# the five alpine-derived platforms build in parallel, and tomcat/springboot
# are wired to the openjdk target via named contexts (`target:openjdk`), so
# bake orders them automatically and shares every common layer in BuildKit.
#
# Driven by scripts/local-build-test.sh; variables are overridden from env
# (PREFIX, *_VER, BUILD_DATE, VCS_REF, VERSION).

variable "PREFIX" { default = "golden-local" }
variable "ALPINE_VER" { default = "3.24" }
variable "DEBIAN_VER" { default = "13" }
variable "REDHAT_VER" { default = "10" }
variable "BUILD_DATE" { default = "" }
variable "VCS_REF" { default = "local" }
variable "VERSION" { default = "1.0.0" }

group "bases" {
  targets = ["base-alpine", "base-debian", "base-redhat"]
}

group "default" {
  targets = ["base-alpine", "base-debian", "nginx", "python"]
}

group "all" {
  targets = [
    "base-alpine", "base-debian", "base-redhat",
    "nginx", "python", "openjdk", "tomcat", "springboot", "aspnet", "dotnet",
  ]
}

target "_common" {
  context    = "."
  provenance = false # local test images; skip attestation manifests for speed
  args = {
    BUILD_DATE = BUILD_DATE
    VCS_REF    = VCS_REF
    VERSION    = VERSION
  }
}

# ---- base images -------------------------------------------------------------

target "base-alpine" {
  inherits   = ["_common"]
  dockerfile = "base-images/alpine/Dockerfile.${ALPINE_VER}"
  tags       = ["${PREFIX}/alpine-hardened:${ALPINE_VER}"]
}

target "base-debian" {
  inherits   = ["_common"]
  dockerfile = "base-images/debian/Dockerfile.${DEBIAN_VER}"
  tags       = ["${PREFIX}/debian-hardened:${DEBIAN_VER}"]
}

target "base-redhat" {
  inherits   = ["_common"]
  dockerfile = "base-images/redhat/Dockerfile.${REDHAT_VER}"
  tags       = ["${PREFIX}/redhat-hardened:${REDHAT_VER}"]
}

# ---- platform images (all on the hardened Alpine base) ------------------------
# BASE_IMAGE is resolved through a named context pointing at another bake
# target, so derived images consume the freshly built base without a push/pull
# round-trip and bake schedules the dependency ordering itself.

target "_platform" {
  inherits = ["_common"]
  contexts = { golden-base = "target:base-alpine" }
  args     = { BASE_IMAGE = "golden-base" }
}

target "nginx" {
  inherits   = ["_platform"]
  dockerfile = "platform-images/nginx/Dockerfile"
  tags       = ["${PREFIX}/nginx-platform:local"]
}

target "python" {
  inherits   = ["_platform"]
  dockerfile = "platform-images/python/Dockerfile"
  tags       = ["${PREFIX}/python-platform:local"]
}

target "openjdk" {
  inherits   = ["_platform"]
  dockerfile = "platform-images/openjdk/Dockerfile"
  tags       = ["${PREFIX}/openjdk-platform:local"]
}

target "aspnet" {
  inherits   = ["_platform"]
  dockerfile = "platform-images/aspnet/Dockerfile"
  tags       = ["${PREFIX}/aspnet-platform:local"]
}

target "dotnet" {
  inherits   = ["_platform"]
  dockerfile = "platform-images/dotnet/Dockerfile"
  tags       = ["${PREFIX}/dotnet-platform:local"]
}

# JVM-derived platforms build on the openjdk platform target, not the raw base.

target "tomcat" {
  inherits   = ["_common"]
  dockerfile = "platform-images/tomcat/Dockerfile"
  contexts   = { golden-jdk = "target:openjdk" }
  args       = { BASE_IMAGE = "golden-jdk" }
  tags       = ["${PREFIX}/tomcat-platform:local"]
}

target "springboot" {
  inherits   = ["_common"]
  dockerfile = "platform-images/springboot/Dockerfile"
  contexts   = { golden-jdk = "target:openjdk" }
  args       = { BASE_IMAGE = "golden-jdk" }
  tags       = ["${PREFIX}/springboot-platform:local"]
}
