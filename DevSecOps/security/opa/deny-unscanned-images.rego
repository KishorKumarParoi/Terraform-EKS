package devsecops.image

default deny = false

deny if {
  input.kind == "Deployment"
  some container in input.spec.template.spec.containers
  not startswith(container.image, "registry.local/scanned/")
}
