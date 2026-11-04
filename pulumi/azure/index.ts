// Infraestructura en Azure: la misma de azure/ (Terraform), escrita con Pulumi.
// Red virtual, firewalls de frontend y backend, dos VMs con cloud-init.

import * as compute from "@pulumi/azure-native/compute";
import * as network from "@pulumi/azure-native/network";
import * as resources from "@pulumi/azure-native/resources";
import * as pulumi from "@pulumi/pulumi";
import * as random from "@pulumi/random";
import { clavesSsh, cloudInit } from "../comun/cloud-init";

// ---------------------------------------------------------------- Configuración
// Valores por defecto en Pulumi.yaml; se cambian con "pulumi config set <clave> <valor>".
const config = new pulumi.Config();
const proyecto = config.require("proyecto");
const sshPermitido = config.require("sshPermitido");
const usuarioAdmin = config.require("usuarioAdmin");
const tamanoBackend = config.require("tamanoBackend");
const tamanoFrontend = config.require("tamanoFrontend");
const discoBackendGb = config.requireNumber("discoBackendGb");
const puertoBackend = config.requireNumber("puertoBackend");
const ipPrivadaBackend = config.require("ipPrivadaBackend");
const ipPrivadaFrontend = config.require("ipPrivadaFrontend");
const appRepo = config.require("appRepo");
const appRama = config.require("appRama");
const adminEmail = config.require("adminEmail");

const claves = clavesSsh();
const etiquetas = { Proyecto: proyecto, Gestionado: "pulumi" };

// ---------------------------------------------------------------- Red
const grupo = new resources.ResourceGroup("rg", {
    resourceGroupName: `rg-${proyecto}`,
    tags: etiquetas,
});

const base = { resourceGroupName: grupo.name, tags: etiquetas };

// La subred va dentro de la red virtual: así Pulumi no intenta borrarla en cada cambio.
const vnet = new network.VirtualNetwork("vnet", {
    ...base,
    virtualNetworkName: `vnet-${proyecto}`,
    addressSpace: { addressPrefixes: ["10.0.0.0/16"] },
    subnets: [
        {
            name: "snet-servidores",
            addressPrefix: "10.0.1.0/24",
            defaultOutboundAccess: false,
        },
    ],
});
const subredId = vnet.subnets.apply((subredes) => subredes![0].id!);

// IPs públicas fijas: la entrada y la salida a internet pasan por ellas.
function ipPublica(rol: string) {
    return new network.PublicIPAddress(`pip-${rol}`, {
        ...base,
        publicIpAddressName: `pip-${proyecto}-${rol}`,
        publicIPAllocationMethod: "Static",
        sku: { name: "Standard" },
    });
}
const pipFrontend = ipPublica("frontend");
const pipBackend = ipPublica("backend");

// ---------------------------------------------------------------- Seguridad
// Grupo de aplicación: permite reglas "desde el frontend" sin usar IPs.
const asgFrontend = new network.ApplicationSecurityGroup("asg-frontend", {
    ...base,
    applicationSecurityGroupName: `asg-${proyecto}-frontend`,
});

const reglaEntrada = {
    direction: "Inbound",
    access: "Allow",
    protocol: "Tcp",
    sourcePortRange: "*",
    destinationAddressPrefix: "*",
};

// Frontend: web abierta a internet, SSH según sshPermitido.
const nsgFrontend = new network.NetworkSecurityGroup("nsg-frontend", {
    ...base,
    networkSecurityGroupName: `nsg-${proyecto}-frontend`,
    securityRules: [
        { ...reglaEntrada, name: "permitir-http", priority: 100, destinationPortRange: "80", sourceAddressPrefix: "Internet" },
        { ...reglaEntrada, name: "permitir-https", priority: 110, destinationPortRange: "443", sourceAddressPrefix: "Internet" },
        { ...reglaEntrada, name: "permitir-ssh-admin", priority: 120, destinationPortRange: "22", sourceAddressPrefix: sshPermitido },
    ],
});

// Backend: API solo desde el frontend; el resto de la red bloqueado (incluido 5432).
const nsgBackend = new network.NetworkSecurityGroup("nsg-backend", {
    ...base,
    networkSecurityGroupName: `nsg-${proyecto}-backend`,
    securityRules: [
        {
            ...reglaEntrada,
            name: "permitir-api-desde-frontend",
            priority: 100,
            destinationPortRange: String(puertoBackend),
            sourceApplicationSecurityGroups: [{ id: asgFrontend.id }],
        },
        { ...reglaEntrada, name: "permitir-ssh-admin", priority: 110, destinationPortRange: "22", sourceAddressPrefix: sshPermitido },
        {
            name: "denegar-resto-de-la-red",
            priority: 4000,
            direction: "Inbound",
            access: "Deny",
            protocol: "*",
            sourcePortRange: "*",
            destinationPortRange: "*",
            sourceAddressPrefix: "VirtualNetwork",
            destinationAddressPrefix: "*",
        },
    ],
});

// Tarjetas de red con IP privada fija.
const nicFrontend = new network.NetworkInterface("nic-frontend", {
    ...base,
    networkInterfaceName: `nic-${proyecto}-frontend`,
    networkSecurityGroup: { id: nsgFrontend.id },
    ipConfigurations: [
        {
            name: "interna",
            subnet: { id: subredId },
            privateIPAllocationMethod: "Static",
            privateIPAddress: ipPrivadaFrontend,
            publicIPAddress: { id: pipFrontend.id },
            applicationSecurityGroups: [{ id: asgFrontend.id }],
        },
    ],
});

const nicBackend = new network.NetworkInterface("nic-backend", {
    ...base,
    networkInterfaceName: `nic-${proyecto}-backend`,
    networkSecurityGroup: { id: nsgBackend.id },
    ipConfigurations: [
        {
            name: "interna",
            subnet: { id: subredId },
            privateIPAllocationMethod: "Static",
            privateIPAddress: ipPrivadaBackend,
            publicIPAddress: { id: pipBackend.id },
        },
    ],
});

// ---------------------------------------------------------------- Aplicación
// Secretos generados (Pulumi los guarda cifrados en el estado).
const dbPassword = new random.RandomPassword("db", { length: 24, special: false });
const jwtSecret = new random.RandomPassword("jwt", { length: 48, special: false });
const adminPassword = new random.RandomPassword("admin", { length: 16, special: false });

// cloud-init (cloud-init/ubuntu/). En Azure va en base64 y las claves SSH van aparte.
const customDataBackend = pulumi
    .all([pipFrontend.ipAddress, dbPassword.result, jwtSecret.result, adminPassword.result])
    .apply(([ip, db, jwt, admin]) =>
        Buffer.from(
            cloudInit("ubuntu", "backend.yaml", {
                repo_url: appRepo,
                rama: appRama,
                puerto_api: puertoBackend,
                cors_origin: `http://${ip}`,
                db_password: db,
                jwt_secret: jwt,
                admin_email: adminEmail,
                admin_password: admin,
            }),
        ).toString("base64"),
    );

const customDataFrontend = Buffer.from(
    cloudInit("ubuntu", "frontend.yaml", {
        repo_url: appRepo,
        rama: appRama,
        ip_backend: ipPrivadaBackend,
        puerto_api: puertoBackend,
    }),
).toString("base64");

// ---------------------------------------------------------------- Servidores
// Ubuntu Server 24.04 LTS (usa apt).
const imagenUbuntu = {
    publisher: "Canonical",
    offer: "ubuntu-24_04-lts",
    sku: "server",
    version: "latest",
};

function servidor(
    rol: "backend" | "frontend",
    tamano: string,
    nic: network.NetworkInterface,
    customData: pulumi.Input<string>,
    discoGb?: number,
) {
    return new compute.VirtualMachine(
        `vm-${rol}`,
        {
            ...base,
            vmName: `vm-${proyecto}-${rol}`,
            tags: { ...etiquetas, Rol: rol },
            hardwareProfile: { vmSize: tamano },
            networkProfile: { networkInterfaces: [{ id: nic.id, primary: true }] },
            osProfile: {
                computerName: `${rol}`,
                adminUsername: usuarioAdmin,
                customData,
                linuxConfiguration: {
                    disablePasswordAuthentication: true,
                    // Una clave por integrante (archivos .pub de la carpeta claves/).
                    ssh: {
                        publicKeys: claves.map((clave) => ({
                            path: `/home/${usuarioAdmin}/.ssh/authorized_keys`,
                            keyData: clave,
                        })),
                    },
                },
            },
            storageProfile: {
                imageReference: imagenUbuntu,
                osDisk: {
                    createOption: "FromImage",
                    caching: "ReadWrite",
                    managedDisk: { storageAccountType: "StandardSSD_LRS" },
                    diskSizeGB: discoGb,
                    deleteOption: "Delete", // el disco se borra junto con la VM
                },
            },
        },
        // cloud-init y las claves solo se aplican al crear la VM: si cambian, se recrea.
        { replaceOnChanges: ["osProfile"] },
    );
}

servidor("backend", tamanoBackend, nicBackend, customDataBackend, discoBackendGb);
servidor("frontend", tamanoFrontend, nicFrontend, customDataFrontend);

// ---------------------------------------------------------------- Salidas
// Ver con "pulumi stack output"; las secretas con "pulumi stack output adminContrasena --show-secrets".
export const urlApp = pulumi.interpolate`http://${pipFrontend.ipAddress}`;
export const frontendIpPublica = pipFrontend.ipAddress;
export const backendIpPublica = pipBackend.ipAddress;
export const backendIpPrivada = ipPrivadaBackend;
export const sshFrontend = pulumi.interpolate`ssh -i ~/.ssh/id_ed25519 ${usuarioAdmin}@${pipFrontend.ipAddress}`;
export const sshBackend = pulumi.interpolate`ssh -i ~/.ssh/id_ed25519 ${usuarioAdmin}@${pipBackend.ipAddress}`;
export const adminCorreo = adminEmail;
export const adminContrasena = adminPassword.result; // secreta: --show-secrets
export const verDespliegue = "cloud-init status --wait; sudo tail -n 50 /var/log/cloud-init-output.log";
