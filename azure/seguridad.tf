# Seguridad: firewalls de frontend y backend.

# Grupo de aplicación: permite reglas "desde el frontend" sin usar IPs.
resource "azurerm_application_security_group" "frontend" {
  name                = "asg-${var.proyecto}-frontend"
  resource_group_name = azurerm_resource_group.principal.name
  location            = azurerm_resource_group.principal.location
  tags                = local.etiquetas
}

resource "azurerm_network_interface_application_security_group_association" "frontend" {
  network_interface_id          = azurerm_network_interface.frontend.id
  application_security_group_id = azurerm_application_security_group.frontend.id
}

# Frontend: web abierta a internet, SSH según var.ssh_permitido.
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

resource "azurerm_network_interface_security_group_association" "frontend" {
  network_interface_id      = azurerm_network_interface.frontend.id
  network_security_group_id = azurerm_network_security_group.frontend.id
}

# Backend: API solo desde el frontend; el resto de la red bloqueado (incluido 5432).
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
    source_application_security_group_ids = [azurerm_application_security_group.frontend.id]
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

resource "azurerm_network_interface_security_group_association" "backend" {
  network_interface_id      = azurerm_network_interface.backend.id
  network_security_group_id = azurerm_network_security_group.backend.id
}
