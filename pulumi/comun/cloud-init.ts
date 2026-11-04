// Funciones compartidas por los proyectos de AWS y Azure:
// leer las claves SSH del grupo y preparar los YAML de cloud-init/.

import * as fs from "fs";
import * as path from "path";

// Carpeta raíz del repositorio (pulumi/comun/ → ../../).
const raiz = path.join(__dirname, "..", "..");

// Claves públicas SSH del grupo (carpeta claves/), igual que en Terraform.
export function clavesSsh(): string[] {
    const carpeta = path.join(raiz, "claves");
    const claves = fs
        .readdirSync(carpeta)
        .filter((archivo) => archivo.endsWith(".pub"))
        .sort()
        .map((archivo) => fs.readFileSync(path.join(carpeta, archivo), "utf8").trim());

    if (claves.length === 0) {
        throw new Error("No hay claves en la carpeta claves/. Agrega al menos un archivo .pub.");
    }
    return claves;
}

// Lee cloud-init/<sistema>/<archivo> y reemplaza las variables ${nombre}.
// Las variables de bash ($VARIABLE, sin llaves) no se tocan.
// Si el YAML pide una variable que no se pasó, falla en vez de dejarla vacía.
export function cloudInit(
    sistema: "amazon-linux" | "ubuntu",
    archivo: "backend.yaml" | "frontend.yaml",
    valores: Record<string, string | number>,
): string {
    const ruta = path.join(raiz, "cloud-init", sistema, archivo);
    const plantilla = fs.readFileSync(ruta, "utf8");

    return plantilla.replace(/\$\{(\w+)\}/g, (_texto, nombre: string) => {
        if (!(nombre in valores)) {
            throw new Error(`${ruta} usa \${${nombre}}, pero no se le pasó ese valor.`);
        }
        return String(valores[nombre]);
    });
}

// Agrega las claves SSH al final del cloud-config (lo usa AWS, igual que Terraform).
export function conClavesSsh(cloudConfig: string, claves: string[]): string {
    const lista = claves.map((clave) => `  - ${JSON.stringify(clave)}`).join("\n");
    return `${cloudConfig}\nssh_authorized_keys:\n${lista}\n`;
}
