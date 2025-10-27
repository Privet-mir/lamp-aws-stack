package terraform

# Deny any Terraform plan that includes resource deletions

deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.change.actions[_] == "delete"
  msg := sprintf("Terraform plan attempts to delete resource: %s", [rc.address])
}


