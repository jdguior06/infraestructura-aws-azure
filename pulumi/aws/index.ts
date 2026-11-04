// Infraestructura en AWS: la misma de aws/ (Terraform), escrita con Pulumi.
// Red pública, firewalls de frontend y backend, dos servidores con cloud-init.

import * as aws from "@pulumi/aws";
import * as pulumi from "@pulumi/pulumi";
import * as random from "@pulumi/random";
import { clavesSsh, cloudInit, conClavesSsh } from "../comun/cloud-init";

// ---------------------------------------------------------------- Configuración
// Valores por defecto en Pulumi.yaml; se cambian con "pulumi config set <clave> <valor>".
const config = new pulumi.Config();
const proyecto = config.require("proyecto");
const sshPermitido = config.require("sshPermitido");
const tipoInstanciaBackend = config.require("tipoInstanciaBackend");
const tipoInstanciaFrontend = config.require("tipoInstanciaFrontend");
const discoBackendGb = config.requireNumber("discoBackendGb");
const puertoBackend = config.requireNumber("puertoBackend");
const appRepo = config.require("appRepo");
const appRama = config.require("appRama");
const adminEmail = config.require("adminEmail");

const claves = clavesSsh();

// Etiquetas para todo lo que se crea (como default_tags en Terraform).
const etiquetas = { Proyecto: proyecto, Gestionado: "pulumi" };

// ---------------------------------------------------------------- Red
const zonas = aws.getAvailabilityZonesOutput({ state: "available" });

const vpc = new aws.ec2.Vpc("vpc", {
    cidrBlock: "10.0.0.0/16",
    enableDnsSupport: true,
    enableDnsHostnames: true,
    tags: { ...etiquetas, Name: `${proyecto}-vpc` },
});

const igw = new aws.ec2.InternetGateway("igw", {
    vpcId: vpc.id,
    tags: { ...etiquetas, Name: `${proyecto}-igw` },
});

const subredPublica = new aws.ec2.Subnet("subred-publica", {
    vpcId: vpc.id,
    cidrBlock: "10.0.1.0/24",
    availabilityZone: zonas.names[0],
    mapPublicIpOnLaunch: true,
    tags: { ...etiquetas, Name: `${proyecto}-subred-publica` },
});

const rutasPublicas = new aws.ec2.RouteTable("rt-publica", {
    vpcId: vpc.id,
    routes: [{ cidrBlock: "0.0.0.0/0", gatewayId: igw.id }],
    tags: { ...etiquetas, Name: `${proyecto}-rt-publica` },
});

new aws.ec2.RouteTableAssociation("rt-publica", {
    subnetId: subredPublica.id,
    routeTableId: rutasPublicas.id,
});

// ---------------------------------------------------------------- Seguridad
// Frontend: web abierta a internet, SSH según sshPermitido.
const sgFrontend = new aws.ec2.SecurityGroup("sg-frontend", {
    name: `${proyecto}-sg-frontend`,
    description: "Web publica y SSH",
    vpcId: vpc.id,
    tags: { ...etiquetas, Name: `${proyecto}-sg-frontend` },
});

const reglasFrontend: [string, number, string][] = [
    ["http", 80, "0.0.0.0/0"],
    ["https", 443, "0.0.0.0/0"],
    ["ssh", 22, sshPermitido],
];
for (const [nombre, puerto, origen] of reglasFrontend) {
    new aws.vpc.SecurityGroupIngressRule(`frontend-${nombre}`, {
        securityGroupId: sgFrontend.id,
        description: `${nombre.toUpperCase()} desde ${origen}`,
        ipProtocol: "tcp",
        fromPort: puerto,
        toPort: puerto,
        cidrIpv4: origen,
    });
}

new aws.vpc.SecurityGroupEgressRule("frontend-salida", {
    securityGroupId: sgFrontend.id,
    description: "Salida libre: paquetes, GitHub y la API del backend",
    ipProtocol: "-1",
    cidrIpv4: "0.0.0.0/0",
});

// Backend: la API solo acepta tráfico del frontend; PostgreSQL no se expone.
const sgBackend = new aws.ec2.SecurityGroup("sg-backend", {
    name: `${proyecto}-sg-backend`,
    description: "API solo desde el frontend y SSH",
    vpcId: vpc.id,
    tags: { ...etiquetas, Name: `${proyecto}-sg-backend` },
});

new aws.vpc.SecurityGroupIngressRule("backend-api", {
    securityGroupId: sgBackend.id,
    description: "API desde el servidor frontend",
    ipProtocol: "tcp",
    fromPort: puertoBackend,
    toPort: puertoBackend,
    referencedSecurityGroupId: sgFrontend.id,
});

new aws.vpc.SecurityGroupIngressRule("backend-ssh", {
    securityGroupId: sgBackend.id,
    description: `SSH desde ${sshPermitido}`,
    ipProtocol: "tcp",
    fromPort: 22,
    toPort: 22,
    cidrIpv4: sshPermitido,
});

new aws.vpc.SecurityGroupEgressRule("backend-salida", {
    securityGroupId: sgBackend.id,
    description: "Salida libre: paquetes y GitHub",
    ipProtocol: "-1",
    cidrIpv4: "0.0.0.0/0",
});

// ---------------------------------------------------------------- Aplicación
// Secretos generados (Pulumi los guarda cifrados en el estado).
const dbPassword = new random.RandomPassword("db", { length: 24, special: false });
const jwtSecret = new random.RandomPassword("jwt", { length: 48, special: false });
const adminPassword = new random.RandomPassword("admin", { length: 16, special: false });

// IP fija del frontend. Se crea antes que los servidores porque el backend
// la necesita (CORS_ORIGIN); luego se asocia al frontend.
const ipFrontend = new aws.ec2.Eip(
    "ip-frontend",
    { domain: "vpc", tags: { ...etiquetas, Name: `${proyecto}-ip-frontend` } },
    { dependsOn: [igw] },
);

// ---------------------------------------------------------------- Servidores
// Amazon Linux 2023 más reciente (usa dnf).
const amazonLinux = aws.ec2.getAmiOutput({
    mostRecent: true,
    owners: ["amazon"],
    filters: [
        { name: "name", values: ["al2023-ami-2023.*-x86_64"] },
        { name: "architecture", values: ["x86_64"] },
        { name: "virtualization-type", values: ["hvm"] },
    ],
});

// cloud-init del backend (cloud-init/amazon-linux/backend.yaml), con las contraseñas.
const userDataBackend = pulumi
    .all([ipFrontend.publicIp, dbPassword.result, jwtSecret.result, adminPassword.result])
    .apply(([ip, db, jwt, admin]) =>
        conClavesSsh(
            cloudInit("amazon-linux", "backend.yaml", {
                repo_url: appRepo,
                rama: appRama,
                puerto_api: puertoBackend,
                cors_origin: `http://${ip}`,
                db_password: db,
                jwt_secret: jwt,
                admin_email: adminEmail,
                admin_password: admin,
            }),
            claves,
        ),
    );

const backend = new aws.ec2.Instance(
    "backend",
    {
        ami: amazonLinux.id,
        instanceType: tipoInstanciaBackend,
        subnetId: subredPublica.id,
        vpcSecurityGroupIds: [sgBackend.id],
        // cloud-init solo corre en el primer arranque: si cambia, se recrea el servidor.
        userData: userDataBackend,
        userDataReplaceOnChange: true,
        rootBlockDevice: { volumeSize: discoBackendGb, volumeType: "gp3", encrypted: true },
        metadataOptions: { httpTokens: "required" }, // IMDSv2
        tags: { ...etiquetas, Name: `${proyecto}-backend`, Rol: "backend" },
    },
    // No recrear el servidor cuando AWS publique una imagen nueva.
    { ignoreChanges: ["ami"] },
);

// cloud-init del frontend: compila React y configura Nginx hacia la IP privada del backend.
const userDataFrontend = backend.privateIp.apply((ipBackend) =>
    conClavesSsh(
        cloudInit("amazon-linux", "frontend.yaml", {
            repo_url: appRepo,
            rama: appRama,
            ip_backend: ipBackend,
            puerto_api: puertoBackend,
        }),
        claves,
    ),
);

const frontend = new aws.ec2.Instance(
    "frontend",
    {
        ami: amazonLinux.id,
        instanceType: tipoInstanciaFrontend,
        subnetId: subredPublica.id,
        vpcSecurityGroupIds: [sgFrontend.id],
        userData: userDataFrontend,
        userDataReplaceOnChange: true,
        rootBlockDevice: { volumeType: "gp3", encrypted: true },
        metadataOptions: { httpTokens: "required" },
        tags: { ...etiquetas, Name: `${proyecto}-frontend`, Rol: "frontend" },
    },
    { ignoreChanges: ["ami"] },
);

new aws.ec2.EipAssociation("ip-frontend", {
    instanceId: frontend.id,
    allocationId: ipFrontend.id,
});

// ---------------------------------------------------------------- Salidas
// Ver con "pulumi stack output"; las secretas con "pulumi stack output adminContrasena --show-secrets".
export const urlApp = pulumi.interpolate`http://${ipFrontend.publicIp}`;
export const frontendIpPublica = ipFrontend.publicIp;
export const backendIpPublica = backend.publicIp; // solo para SSH; cambia si el servidor se detiene
export const backendIpPrivada = backend.privateIp;
export const sshFrontend = pulumi.interpolate`ssh -i ~/.ssh/id_ed25519 ec2-user@${ipFrontend.publicIp}`;
export const sshBackend = pulumi.interpolate`ssh -i ~/.ssh/id_ed25519 ec2-user@${backend.publicIp}`;
export const adminCorreo = adminEmail;
export const adminContrasena = adminPassword.result; // secreta: --show-secrets
export const verDespliegue = "cloud-init status --wait; sudo tail -n 50 /var/log/cloud-init-output.log";
