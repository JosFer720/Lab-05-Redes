# Diagnóstico VirtualBox y Windows

Ejecutar `powershell -NoProfile -ExecutionPolicy Bypass -File virtualbox/diagnostico-host.ps1`
desde la raíz. Descubre VBoxManage por PATH o instalación estándar y registra VMs,
interfaces/MAC, DHCP, NAT, recursos, rutas y DNS. Es de solo lectura salvo escritura
de evidencias. Las consultas DISM requieren elevación; el script conserva el error
cuando no existe, sin modificar funciones opcionales.

Decisión del 11 de octubre: usar Docker existente. GNS3 VM está saved y pertenece
a otro proyecto; no se enciende ni reutiliza. RAM libre insuficiente para otra VM
de 3-4 GiB. Se conserva la MAC VirtualBox generada. No se crea Ubuntu ni se configura
bridge/IP/reserva DHCP sin una necesidad y red real confirmadas.

El montaje activo se arranca/detiene con Docker Compose; instrucciones completas
en ../docs/instrucciones-arranque.md. No ejecutar dns/windows/lan-on.ps1 como parte
de este montaje: cambia .wslconfig y detiene todas las distros, incluida Docker.
