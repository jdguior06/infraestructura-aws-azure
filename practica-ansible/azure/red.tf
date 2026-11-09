# Red: red virtual, subred, IPs públicas y tarjetas de red.

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

# Una IP pública fija por servidor: entrada (SSH/web) y salida a internet.
resource "azurerm_public_ip" "servidor" {
  for_each = local.roles

  name                = "pip-${var.proyecto}-${each.key}"
  resource_group_name = azurerm_resource_group.principal.name
  location            = azurerm_resource_group.principal.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.etiquetas
}

# Tarjetas de red con IP privada fija.
resource "azurerm_network_interface" "servidor" {
  for_each = local.roles

  name                = "nic-${var.proyecto}-${each.key}"
  resource_group_name = azurerm_resource_group.principal.name
  location            = azurerm_resource_group.principal.location
  tags                = local.etiquetas

  ip_configuration {
    name                          = "interna"
    subnet_id                     = azurerm_subnet.servidores.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.ip_privada[each.key]
    public_ip_address_id          = azurerm_public_ip.servidor[each.key].id
  }
}
