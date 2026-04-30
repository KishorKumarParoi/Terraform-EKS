package devsecops.image

default deny = false

deny if {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not startswith(container.image, "registry.local/scanned/")
}
