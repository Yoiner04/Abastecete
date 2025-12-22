using DataAccess;
using BusinessLogic.Models;
using System;
using System.Collections.Generic;
using System.Data;

namespace BusinessLogic
{
    /// <summary>
    /// Manejador para operaciones de logs de auditoría
    /// </summary>
    public class ManejadorLogs
    {
        private readonly Connection conexion;

        public ManejadorLogs()
        {
            conexion = new Connection();
        }

        /// <summary>
        /// Registra un log en el sistema
        /// </summary>
        public bool RegistrarLog(
            int? usuarioId,
            string nombreUsuario,
            string modulo,
            string tipoAccion,
            int? entidadId,
            string entidadDescripcion,
            string datosAnteriores,
            string datosNuevos,
            string ipCliente,
            string userAgent,
            string resultado,
            string mensajeError,
            string controller,
            string action)
        {
            try
            {
                // DEBUG: Imprimir parametros para verificar que se estan enviando correctamente
                Console.WriteLine($"[LOG DEBUG] Registrando: usuario={usuarioId}, modulo={modulo}, accion={tipoAccion}, resultado={resultado}");

                // Usar null en lugar de DBNull.Value - MySQL.Data lo maneja mejor
                var parametros = new List<Parametro>
                {
                    new Parametro("p_id_usuario", usuarioId.HasValue ? (object)usuarioId.Value : null),
                    new Parametro("p_nombre_usuario", nombreUsuario ?? ""),
                    new Parametro("p_modulo", modulo ?? ""),
                    new Parametro("p_tipo_accion", tipoAccion ?? ""),
                    new Parametro("p_entidad_id", entidadId.HasValue ? (object)entidadId.Value : null),
                    new Parametro("p_entidad_descripcion", entidadDescripcion ?? ""),
                    new Parametro("p_datos_anteriores", string.IsNullOrEmpty(datosAnteriores) ? null : datosAnteriores),
                    new Parametro("p_datos_nuevos", string.IsNullOrEmpty(datosNuevos) ? null : datosNuevos),
                    new Parametro("p_ip_cliente", ipCliente ?? ""),
                    new Parametro("p_user_agent", string.IsNullOrEmpty(userAgent) ? "" : (userAgent.Length > 500 ? userAgent.Substring(0, 500) : userAgent)),
                    new Parametro("p_resultado", resultado ?? "EXITO"),
                    new Parametro("p_mensaje_error", mensajeError ?? ""),
                    new Parametro("p_controller", controller ?? ""),
                    new Parametro("p_action", action ?? "")
                };

                bool exito = conexion.EjecutarTransaccion("insertar_log_sistema", parametros);
                Console.WriteLine($"[LOG DEBUG] Resultado de insertar_log_sistema: {exito}");
                return exito;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[LOG ERROR] Error al registrar log: {ex.Message}");
                Console.WriteLine($"[LOG ERROR] StackTrace: {ex.StackTrace}");
                return false;
            }
        }

        /// <summary>
        /// Consulta logs con filtros y paginación
        /// </summary>
        public ResultadoPaginado<LogSistema> ConsultarLogs(
            DateTime? fechaDesde,
            DateTime? fechaHasta,
            string modulo,
            string tipoAccion,
            int? usuarioId,
            string terminoBusqueda,
            int pagina,
            int registrosPorPagina)
        {
            var resultado = new ResultadoPaginado<LogSistema>
            {
                PaginaActual = pagina,
                RegistrosPorPagina = registrosPorPagina
            };

            try
            {
                // Obtener total de registros
                var parametrosCount = CrearParametrosFiltro(
                    fechaDesde, fechaHasta, modulo, tipoAccion, usuarioId, terminoBusqueda);

                DataTable countResult = conexion.EjecutarConsulta("contar_logs_sistema", parametrosCount);
                if (countResult.Rows.Count > 0)
                {
                    resultado.TotalRegistros = Convert.ToInt32(countResult.Rows[0]["TotalRegistros"]);
                }

                // Obtener registros paginados
                var parametros = CrearParametrosFiltro(
                    fechaDesde, fechaHasta, modulo, tipoAccion, usuarioId, terminoBusqueda);
                parametros.Add(new Parametro("p_pagina", pagina));
                parametros.Add(new Parametro("p_registros_por_pagina", registrosPorPagina));

                DataTable datos = conexion.EjecutarConsulta("consultar_logs_sistema", parametros);

                foreach (DataRow row in datos.Rows)
                {
                    resultado.Items.Add(MapearLog(row));
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al consultar logs: {ex.Message}");
            }

            return resultado;
        }

        /// <summary>
        /// Obtiene estadísticas de logs para el dashboard
        /// </summary>
        public (int creates, int updates, int deletes) ObtenerEstadisticas(DateTime? fechaDesde, DateTime? fechaHasta)
        {
            var logs = ConsultarLogs(fechaDesde, fechaHasta, null, null, null, null, 1, 10000);

            int creates = 0, updates = 0, deletes = 0;
            foreach (var log in logs.Items)
            {
                switch (log.TipoAccion)
                {
                    case "CREATE": creates++; break;
                    case "UPDATE": updates++; break;
                    case "DELETE": deletes++; break;
                }
            }

            return (creates, updates, deletes);
        }

        private List<Parametro> CrearParametrosFiltro(
            DateTime? fechaDesde,
            DateTime? fechaHasta,
            string modulo,
            string tipoAccion,
            int? usuarioId,
            string terminoBusqueda)
        {
            return new List<Parametro>
            {
                new Parametro("p_fecha_desde", fechaDesde.HasValue ? (object)fechaDesde.Value : DBNull.Value),
                new Parametro("p_fecha_hasta", fechaHasta.HasValue ? (object)fechaHasta.Value : DBNull.Value),
                new Parametro("p_modulo", modulo ?? ""),
                new Parametro("p_tipo_accion", tipoAccion ?? ""),
                new Parametro("p_id_usuario", usuarioId ?? 0),
                new Parametro("p_termino_busqueda", terminoBusqueda ?? "")
            };
        }

        private LogSistema MapearLog(DataRow row)
        {
            return new LogSistema
            {
                Id = Convert.ToInt32(row["Id"]),
                UsuarioId = row["UsuarioId"] != DBNull.Value ? Convert.ToInt32(row["UsuarioId"]) : null,
                NombreUsuario = row["NombreUsuario"]?.ToString() ?? "",
                Modulo = row["Modulo"]?.ToString() ?? "",
                TipoAccion = row["TipoAccion"]?.ToString() ?? "",
                EntidadId = row["EntidadId"] != DBNull.Value ? Convert.ToInt32(row["EntidadId"]) : null,
                EntidadDescripcion = row["EntidadDescripcion"]?.ToString() ?? "",
                DatosAnteriores = row["DatosAnteriores"]?.ToString(),
                DatosNuevos = row["DatosNuevos"]?.ToString(),
                IpCliente = row["IpCliente"]?.ToString() ?? "",
                UserAgent = row["UserAgent"]?.ToString() ?? "",
                FechaRegistro = Convert.ToDateTime(row["FechaRegistro"]),
                Resultado = row["Resultado"]?.ToString() ?? "EXITO",
                MensajeError = row["MensajeError"]?.ToString(),
                Controller = row["Controller"]?.ToString() ?? "",
                Action = row["Action"]?.ToString() ?? ""
            };
        }
    }
}
