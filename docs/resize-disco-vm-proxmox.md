# Receta: Redimensionar disco de VM en Proxmox (guest Linux con LVM)

> Escenario: agrandaste el disco de una VM en Proxmox (`qm resize`), reiniciaste,
> y `df -h` sigue mostrando el tamaño viejo. **El reboot no es el paso que falta.**

## Por qué pasa (la cebolla de 4 capas)

Un disco agrandado no es una acción, es una **transacción de 4 capas** y cada una
debe enterarse por separado:

```
┌─ Capa 4: FILESYSTEM (ext4/xfs)   ← lo que df -h reporta
├─ Capa 3: LVM (LV → VG → PV)      ← la capa de flexibilidad
├─ Capa 2: PARTICIÓN (sda3)        ← la tabla del disco
└─ Capa 1: DISCO VIRTUAL (sda)     ← lo que el hipervisor le presta a la VM
```

`qm resize` en Proxmox solo toca la **capa 1**: el hipervisor le dice a la VM
"ahora tienes N GB" y ahí termina su jurisdicción. El kernel del guest **no
reescribe tablas de particiones por diseño** (imagina si el SO moviera tus
particiones solo). Igual LVM y el filesystem: nadie arriba sabe que abajo hay
espacio nuevo.

## Paso 0 — Diagnóstico (siempre antes de tocar)

```bash
lsblk /dev/sda    # ¿de qué tamaño VE el guest el disco? (capa 1)
df -h /           # ¿de qué tamaño vive el filesystem? (capa 4)
```

La **diferencia entre esos dos números** = espacio atrapado en las capas
intermedias. Si `lsblk` ya muestra el tamaño nuevo, Proxmox hizo su parte y el
problema es 100% interno del guest.

> Si `lsblk` muestra el tamaño VIEJO: el resize no llegó al guest (disco hot-plug
> deshabilitado, VM apagada al momento del resize, o te equivocaste de disco).
> Arregla eso primero — nada de lo siguiente aplica.

## Paso 1 — Partición: `growpart`

```bash
sudo growpart /dev/sda 3
# CHANGED: partition=3 old: size=62908416 new: size=167768031
```

- El `3` es el número de partición que viste en `lsblk` (la que monta `/`).
- growpart recalcula y reescribe **solo la entrada de la tabla** moviendo el
  final de la partición al nuevo borde. No toca un byte de datos.
- Los números son sectores de 512B: 62.9M → 167.7M sectores ≈ 30G → 80G.

## Paso 2 — Physical Volume: `pvresize`

```bash
sudo pvresize /dev/sda3
# Physical volume "/dev/sda3" changed
```

Le dice a LVM "el PV ahora abarca la partición completa". El VG acumula los
extents libres nuevos. Verifica con `sudo vgs` (columna `VFree`).

## Paso 3 — Logical Volume + filesystem: `lvextend -r`

```bash
sudo lvextend -l +100%FREE -r /dev/ubuntu-vg/ubuntu-lv
```

- `-l +100%FREE` = "tómate todos los extents libres del VG" (unidades LVM,
  más preciso que `-L +65G`).
- **`-r` es la magia**: (`--resizefs`) llama a `resize2fs` automáticamente, con
  el filesystem **montado y en vivo**. Cero downtime.
- El path se lee al revés: `VG/LV`. Ojo con los guiones dobles en los outputs
  (`ubuntu--vg`): LVM escapa los guiones simples, no es un typo.

> **xfs en vez de ext4:** el `-r` también funciona (usa `xfs_growfs` internamente).
> Nunca uses `resize2fs` directo sobre xfs.

## Paso 4 — Verificación (no es opcional)

```bash
lsblk /dev/sda    # sda=82G → sda3=80G → LV=80G   (capas alineadas)
df -h /           # 79G size, 67G avail            (la capa 4 ya lo ve)
```

La tarea se declara `done` **solo cuando `df` reporta el tamaño esperado**.
El exit code 0 de cada comando no es verificación.

## Errores clásicos (el cuaderno de los tropezazos)

| Tropezón | Síntoma | Lección |
|---|---|---|
| Reiniciar esperando que "se refleje" | `df -h` igual tras reboot | El reboot no reescribe tablas ni metadatos |
| `lvextend` sin `-r` | LV grande, `df` chico | Falta `resize2fs`/`xfs_growfs` |
| `resize2fs` sobre fs xfs | error de superbloque | xfs usa `xfs_growfs`, no resize2fs |
| Resize en Proxmox con VM encendida sin hot-plug | `lsblk` muestra tamaño viejo | Verificar paso 0 antes de culpar al guest |
| Extender partición equivocada | pánico | Confirmar con `lsblk` cuál partición monta `/` |

## Caso real de referencia (k3s-o11y, 2026-09-22)

```
Antes:  sda=82G (Proxmox ya había hecho qm resize), sda3=30G, LV=15G, df=15G (5.2G libres)
Comandos: growpart /dev/sda 3 && pvresize /dev/sda3 && lvextend -l +100%FREE -r /dev/ubuntu-vg/ubuntu-lv
Después: sda3=80G, LV=80G, df=79G (67G libres) — filesystem creció montado, cero downtime
```

## Mentalidad SRE

- **Mide antes, mide entre pasos, mime al final.** Cada capa tiene su comando de
  observación (`lsblk`, `vgs`, `lvs`, `df`).
- **Una transacción se completa o se rollbackea conscientemente** — dejarla a
  medias (LV grande, fs chico) deja una bomba para el próximo incidente.
- **Verificar el efecto ≠ confiar en el exit code.** El estado deseado se lee del
  sistema, no del log del comando.
