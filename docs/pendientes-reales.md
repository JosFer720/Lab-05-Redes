# Pendientes que requieren intervención externa

1. Conectar un segundo equipo físico del grupo a la misma red y proporcionar acceso autorizado o ejecutar la matriz desde ese equipo. Confirmar IP actuales de los cinco servidores, puerto LDAP publicado y rutas; no reutilizar 10.223.12.x sin verificarlas.
2. Confirmar un segmento aislado para servicios sin TLS y una IP fija/reservada para DNS con el administrador legítimo del DHCP. No se conoce el pool DHCP del router doméstico y no se modificó.
3. El responsable LDAP remoto debe rotar las credenciales comprometidas y exportar nuevos hashes; coordinar web/correo/Thunderbird. Este montaje local ya tiene seis claves nuevas, pero los fixtures adicionales siguen siendo públicos y solo deben quedar aislados.
4. Instalar/configurar Thunderbird en el cliente autorizado y capturar configuración, login, envío/recepción entre nmolina y jvalladares. MAIL-02/03/06 no aprobados sin esas pruebas. Capturar también navegador/FTP según el PDF. No se fabricaron capturas.
5. Repetir los 33 casos en LAN, incluidos reinicios controlados y WEB-05 con recuperación; guardar máquina/fecha/logs. Revisar el reporte posterior a esa ejecución y validar con docente el dominio ASCII frente a la tilde del PDF y cualquier entrega tardía.

No se requiere crear otra VM para la integración actual. El estado saved de GNS3 y la falta de memoria hacen preferible conservarla. Para inspeccionar funciones Windows opcionales con DISM sí se necesita una consola elevada; esto no bloquea Docker validado.
