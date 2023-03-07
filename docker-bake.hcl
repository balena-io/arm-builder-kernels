variable "GITHUB_SHA" {
  default = "latest"
}

target "default" {
  dockerfile = "Dockerfile"
  platforms = [
    "linux/arm64"
  ]
  tags = ["kernel-builder:${GITHUB_SHA}"]
}
