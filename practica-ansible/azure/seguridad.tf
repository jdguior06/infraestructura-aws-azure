# Seguridad: un firewall por servidor. Cadena: internet → frontend → backend → base.

# Grupos de aplicación: permiten reglas "desde el frontend" o "desde el backend" sin usar IPs.
resource "azurerm_application_security_group" "rol" {
  for_each = toset(["frontend", "backend"])

  name                = "asg-${var.proyecto}-${each.key}"
  resource_group_name = azurerm_resource_group.principal.name
  location            = azurerm_resource_group.principal.location
  tags                = local.etiquetas
}

resource "azurerm_network_interface_application_security_group_association" "rol" {
  for_each = azurerm_application_security_group.rol

  network_interface_id          = azurerm_network_interface.servidor[each.key].id
  application_security_group_id = each.value.id
}

# ---------------------------------------------------------------- Frontend
# Web abierta a internet, SSH según var.ssh_permitido.
resource "azurerm_network_security_group" "frontend" {
  name                = "nsg-${var.proyecto}-frontend"
  resource_group_name = azurerm_resource_group.principal.name
  location            = azurerm_resource_group.principal.location
  tags                = local.etiquetas

  security_rule {
    name                       = "permitir-http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "permitir-https"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "permitir-ssh-admin"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ssh_permitido
    destination_address_prefix = "*"
  }
}

# ---------------------------------------------------------------- Backend
# API solo desde el frontend; el resto de la red bloqueado.
resource "azurerm_network_security_group" "backend" {
  name                = "nsg-${var.proyecto}-backend"
  resource_group_name = azurerm_resource_group.principal.name
  location            = azurerm_resource_group.principal.location
  tags                = local.etiquetas

  security_rule {
    name                                  = "permitir-api-desde-frontend"
    priority                              = 100
    direction                             = "Inbound"
    access                                = "Allow"
    protocol                              = "Tcp"
    source_port_range                     = "*"
    destination_port_range                = tostring(var.puerto_backend)
    source_application_security_group_ids = [azurerm_application_security_group.rol["frontend"].id]
    destination_address_prefix            = "*"
  }

  security_rule {
    name                       = "permitir-ssh-admin"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ssh_permitido
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "denegar-resto-de-la-red"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

# ---------------------------------------------------------------- Base de datos
# PostgreSQL solo desde el backend; ni el frontend ni internet llegan al 5432.
resource "azurerm_network_security_group" "base" {
  name                = "nsg-${var.proyecto}-base"
  resource_group_name = azurerm_resource_group.principal.name
  location            = azurerm_resource_group.principal.location
  tags                = local.etiquetas

  security_rule {
    name                                  = "permitir-postgres-desde-backend"
    priority                              = 100
    direction                             = "Inbound"
    access                                = "Allow"
    protocol                              = "Tcp"
    source_port_range                     = "*"
    destination_port_range                = "5432"
    source_application_security_group_ids = [azurerm_application_security_group.rol["backend"].id]
    destination_address_prefix            = "*"
  }

  security_rule {
    name                       = "permitir-ssh-admin"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ssh_permitido
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "denegar-resto-de-la-red"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

locals {
  firewall = {
    frontend = azurerm_network_security_group.frontend.id
    backend  = azurerm_network_security_group.backend.id
    base     = azurerm_network_security_group.base.id
  }
}

resource "azurerm_network_interface_security_group_association" "servidor" {
  for_each = local.roles

  network_interface_id      = azurerm_network_interface.servidor[each.key].id
  network_security_group_id = local.firewall[each.key]
}
