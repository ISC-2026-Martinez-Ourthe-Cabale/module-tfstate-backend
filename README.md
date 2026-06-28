# 🔐 module-tfstate-backend

**Repositorio:** `ISC-2026-Martinez-Ourthe-Cabale/module-tfstate-backend`
**Lenguaje:** HCL (Terraform)

## ⚠️ Esto NO es un módulo para sourcear desde el orquestador

A diferencia de todos los demás módulos del proyecto, **este no se referencia con un bloque `module "x" { source = ... }`**. Se aplica de forma standalone, una sola vez, con su propio state local — porque crea justamente los recursos que el resto de la infraestructura necesita para tener un backend remoto.

## Por qué existe

Hoy cada persona del equipo tiene su propio `terraform.tfstate` local (está en `.gitignore`, nunca se compartió). Eso significa que si dos personas aplican contra la misma cuenta de AWS, cada una tiene una versión distinta de "qué existe" — riesgo real de infraestructura duplicada o state corrupto.

La solución estándar es un backend remoto:

* **Bucket S3** — guarda el `terraform.tfstate` como un objeto, compartido por todo el equipo.
* **Tabla DynamoDB** — Terraform escribe un ítem (`LockID`) ahí antes de modificar el state, y lo borra al terminar. Si alguien más intenta aplicar mientras el lock existe, espera o falla en vez de pisar el state de otro.

## Por qué es un módulo separado y no parte del orquestador

El bucket y la tabla que van a *contener* el state tienen que existir *antes* de poder usarse como backend — no se puede crear con el mismo `apply` que los va a usar (dependencia circular). Por eso se bootstrapea aparte, con state local, y se queda fuera del ciclo normal de `plan`/`apply`/`destroy` del resto de la infraestructura. Ambos recursos tienen `prevent_destroy = true`: ni un `terraform destroy` accidental de este mismo módulo puede borrarlos.

## Recursos Creados

| Recurso AWS                                          | Descripción                                              |
| ------------------------------------------------------ | ----------------------------------------------------------- |
| `aws_s3_bucket.tfstate`                               | Bucket donde vive el `terraform.tfstate` remoto            |
| `aws_s3_bucket_versioning.tfstate`                    | Versionado, para recuperar un state anterior si algo sale mal |
| `aws_s3_bucket_server_side_encryption_configuration`  | Cifrado AES256 (el state guarda secretos en texto plano, ej. `db_password`) |
| `aws_s3_bucket_public_access_block.tfstate`           | Bloquea todo acceso público                                |
| `aws_dynamodb_table.tfstate_lock`                     | Tabla de lock (`LockID`, on-demand)                        |

## Variables de Entrada

| Variable           | Tipo     | Default                   | Descripción                                          |
| -------------------- | -------- | ---------------------------- | ------------------------------------------------------- |
| `bucket_name`      | `string` | —                            | Nombre del bucket S3. Debe ser globalmente único      |
| `lock_table_name`  | `string` | `"terraform-state-lock"`    | Nombre de la tabla DynamoDB de lock                    |

## Outputs

| Output                | Descripción                                                  |
| ----------------------- | ---------------------------------------------------------------- |
| `bucket_name`          | Para usar en el bloque `backend "s3"` del orquestador            |
| `dynamodb_table_name`  | Para usar en el bloque `backend "s3"` del orquestador            |

## Cómo bootstrapear (una sola vez, lo hace una sola persona del equipo)

```bash
git clone git@github.com:ISC-2026-Martinez-Ourthe-Cabale/module-tfstate-backend.git
cd module-tfstate-backend

terraform init
terraform apply
```

> El `terraform.tfvars` ya está en este repo con `bucket_name = "tfstate-martinez-ourthecabale"`.

Esto deja un `terraform.tfstate` **local** en esta misma carpeta — es la única excepción del proyecto donde el state se queda local a propósito (no hay backend remoto anterior que lo contenga). **Hacer un backup de ese archivo** (o al menos anotar el `bucket_name`/`lock_table_name` elegidos): si se pierde, los recursos son recreables vía `terraform import` porque sus nombres son los que vos elegiste.

## Cómo conectar el orquestador a este backend

Una vez aplicado, agregar en `terraform/main.tf` (valores literales, un bloque `backend` no acepta variables):

```hcl
terraform {
  backend "s3" {
    bucket         = "tfstate-martinez-ourthecabale"
    key            = "obligatorio/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

Después, **cada persona del equipo** (no solo quien bootstrapeó) corre, dentro de `terraform/`:

```bash
terraform init -migrate-state
```

Terraform va a detectar el state local existente y preguntar si lo querés copiar al backend nuevo — confirmar que sí. A partir de ahí, todos comparten el mismo state remoto con lock automático.

> ⚠️ **Coordinar con el equipo antes de este paso.** Si alguien sigue aplicando con state local viejo después de que otro ya migró, se vuelve a la misma situación de states divergentes que se quiere evitar.
