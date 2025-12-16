# Migraciones de Base de Datos - Abastecete

## Descripción

Esta carpeta contiene scripts de migración SQL para corregir problemas de lógica y seguridad en los procedimientos almacenados de la base de datos.

## Orden de Ejecución

Los scripts deben ejecutarse en orden numérico:

1. `001_fix_login_usuario.sql`
2. `002_fix_crear_usuario_persona.sql`
3. `003_fix_recuperar_contrasenia.sql`
4. `004_fix_crear_usuario_google.sql`
5. `005_fix_login_usuario_google.sql`
6. `006_add_security_indexes.sql`

## Cómo Ejecutar

### Opción 1: MySQL Workbench
1. Abrir MySQL Workbench
2. Conectar a la base de datos `abastecete`
3. Abrir cada archivo en orden
4. Ejecutar (Ctrl+Shift+Enter)

### Opción 2: Línea de comandos
```bash
mysql -h 167.71.91.199 -u bd_abastecete -p abastecete < 001_fix_login_usuario.sql
mysql -h 167.71.91.199 -u bd_abastecete -p abastecete < 002_fix_crear_usuario_persona.sql
# ... continuar con los demás
```

### Opción 3: Script combinado
```bash
cat 001_fix_login_usuario.sql 002_fix_crear_usuario_persona.sql 003_fix_recuperar_contrasenia.sql 004_fix_crear_usuario_google.sql 005_fix_login_usuario_google.sql 006_add_security_indexes.sql | mysql -h 167.71.91.199 -u bd_abastecete -p abastecete
```

## Resumen de Correcciones

### 001_fix_login_usuario.sql
- ✅ Retorna estructura consistente en todos los casos
- ✅ Maneja usuario inhabilitado (estado 97)
- ✅ Usa LEFT JOIN para usuarios sin local
- ✅ Agrega índice en NOMBRE_USUARIO

### 002_fix_crear_usuario_persona.sql
- ✅ Usa LAST_INSERT_ID() en vez de ORDER BY DESC
- ✅ Transacción explícita con rollback
- ✅ Valida correo con regex
- ✅ Código de referido único con reintentos
- ✅ Retorna resultado y mensaje

### 003_fix_recuperar_contrasenia.sql
- ✅ Token de 6 dígitos (más fácil de copiar)
- ✅ Límite de 5 intentos por 24 horas
- ✅ Invalida token después de usar
- ✅ Eventos para limpiar tokens expirados

### 004_fix_crear_usuario_google.sql
- ✅ Sin documento/teléfono ficticios
- ✅ Valida correo duplicado
- ✅ Sin contraseña para auth Google
- ✅ Transacción con rollback

### 005_fix_login_usuario_google.sql
- ✅ Verifica estado del usuario
- ✅ Maneja usuarios bloqueados
- ✅ Estructura de respuesta consistente

### 006_add_security_indexes.sql
- ✅ Índices para optimizar consultas de login
- ✅ Índices para búsqueda de tokens

## Cambios Requeridos en el Código C#

Después de aplicar estas migraciones, se recomienda actualizar:

### LoginController.cs
```csharp
// Verificar el nuevo campo estado_login para Google
if (data.Rows[0]["estado_login"].ToString() == "NO_EXISTE") {
    // Registrar nuevo usuario
}
```

### ManejadorUsuario.cs
```csharp
// Los procedimientos ahora retornan 'resultado' y 'mensaje'
// Verificar estos campos para manejo de errores
```

## Backup

**IMPORTANTE:** Antes de ejecutar, hacer backup de la base de datos:

```bash
mysqldump -h 167.71.91.199 -u bd_abastecete -p abastecete > backup_$(date +%Y%m%d_%H%M%S).sql
```

## Notas

- Las migraciones son idempotentes (pueden ejecutarse múltiples veces)
- Se usa `DROP PROCEDURE IF EXISTS` antes de crear
- Los eventos requieren que `event_scheduler` esté habilitado en MySQL
