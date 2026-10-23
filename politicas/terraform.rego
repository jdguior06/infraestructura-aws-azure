# Políticas del equipo, evaluadas sobre el plan de Terraform (terraform show -json).
package main

import rego.v1

# Tamaños de servidor permitidos (controla el costo y la cuota de vCPU).
tamanos_aws := {"t2.micro", "t3.micro", "t3.small"}

tamanos_azure := {"Standard_B2ats_v2", "Standard_D2as_v4"}

# Recursos que se van a crear o modificar.
cambios contains rc if {
	some rc in input.resource_changes
	some accion in rc.change.actions
	accion in {"create", "update"}
}

# DENY: bloquea el plan.
deny contains msg if {
	some rc in cambios
	rc.type == "aws_instance"
	not rc.change.after.instance_type in tamanos_aws
	msg := sprintf("%s usa '%s'; tamaños permitidos: %v", [rc.address, rc.change.after.instance_type, tamanos_aws])
}

deny contains msg if {
	some rc in cambios
	rc.type == "azurerm_linux_virtual_machine"
	not rc.change.after.size in tamanos_azure
	msg := sprintf("%s usa '%s'; tamaños permitidos: %v", [rc.address, rc.change.after.size, tamanos_azure])
}

# WARN: avisa, pero no bloquea.
warn contains msg if {
	some rc in input.resource_changes
	"delete" in rc.change.actions
	msg := sprintf("%s será DESTRUIDO. ¿Hiciste git pull antes del plan?", [rc.address])
}