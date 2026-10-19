# Red: red virtual, subred, IPs y salida a internet.

resource "azurerm_resource_group" "principal" {
  name     = "rg-${var.proyecto}"
  location = var.region
  tags     = local.etiquetas
}

resource "azurerm_virtual_network" "principal" {
  name                = "vnet-${var.proyecto}"
  resource_group_name = azurerm_resource_group.principal.name
  location            = azurerm_resource_group.principal.location
  address_space       = ["10.0.0.0/16"]
  tags                = local.etiquetas
}

resource "azurerm_subnet" "servidores" {
  name                            = "snet-servidores"
  resource_group_name             = azurerm_resource_group.principal.name
  virtual_network_name            = azurerm_virtual_network.principal.name
  address_prefixes                = ["10.0.1.0/24"]
  default_outbound_access_enabled = false
}

# IPs públicas fijas: la entrada y la salida a internet pasan por ellas.
resource "azurerm_public_ip" "frontend" {
  name                = "pip-${var.proyecto}-frontend"
  resource_group_name = azurerm_resource_group.principal.name
  location            = azurerm_resource_group.principal.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.etiquetas
}

resource "azurerm_public_ip" "backend" {
  name                = "pip-${var.proyecto}-backend"
  resource_group_name = azurerm_resource_group.principal.name
  location            = azurerm_resource_group.principal.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.etiquetas
}

# Tarjetas de red con IP privada fija.
resource "azurerm_network_interface" "frontend" {
  name                = "nic-${var.proyecto}-frontend"
  resource_group_name = azurerm_resource_group.principal.name
  location            = azurerm_resource_group.principal.location
  tags                = local.etiquetas

  ip_configuration {
    name                          = "interna"
    subnet_id                     = azurerm_subnet.servidores.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.ip_privada_frontend
    public_ip_address_id          = azurerm_public_ip.frontend.id
  }
}

resource "azurerm_network_interface" "backend" {
  name                = "nic-${var.proyecto}-backend"
  resource_group_name = azurerm_resource_group.principal.name
  location            = azurerm_resource_group.principal.location
  tags                = local.etiquetas

  ip_configuration {
    name                          = "interna"
    subnet_id                     = azurerm_subnet.servidores.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.ip_privada_backend
    public_ip_address_id          = azurerm_public_ip.backend.id
  }
}
