using BusinessLogic;
using BusinessLogic.Interfaces;
using BusinessLogic.Models;
using BusinessLogic.Utilidades;
using Microsoft.AspNetCore.Mvc;
using System;
using System.Text;

namespace Abastecete.Controllers
{
    public class LogsController : Controller
    {
        private readonly IManejadorLogs _manejadorLogs;

        public LogsController(IManejadorLogs manejadorLogs)
        {
            _manejadorLogs = manejadorLogs;
        }

        /// <summary>
        /// Vista principal del panel de logs
        /// </summary>
        [RequierePermiso("Ver Logs Sistema,ADMIN_LOGS")]
        public IActionResult Index(
            DateTime? fechaDesde,
            DateTime? fechaHasta,
            string modulo,
            string tipoAccion,
            int? usuarioId,
            string busqueda,
            int pagina = 1,
            int registrosPorPagina = 25)
        {
            // Si no hay fechas, usar últimos 7 días por defecto
            if (!fechaDesde.HasValue)
                fechaDesde = DateTime.Now.AddDays(-7);
            if (!fechaHasta.HasValue)
                fechaHasta = DateTime.Now.AddDays(1); // +1 día para incluir hoy completo

            var logs = _manejadorLogs.ConsultarLogs(
                fechaDesde,
                fechaHasta,
                modulo,
                tipoAccion,
                usuarioId,
                busqueda,
                pagina,
                registrosPorPagina
            );

            // Pasar filtros a la vista
            ViewBag.FechaDesde = fechaDesde?.ToString("yyyy-MM-dd");
            ViewBag.FechaHasta = fechaHasta?.AddDays(-1).ToString("yyyy-MM-dd"); // Mostrar la fecha real sin el +1
            ViewBag.ModuloSeleccionado = modulo;
            ViewBag.TipoAccionSeleccionado = tipoAccion;
            ViewBag.UsuarioIdSeleccionado = usuarioId;
            ViewBag.Busqueda = busqueda;
            ViewBag.Modulos = ModulosAuditoria.Todos;

            return View(logs);
        }

        /// <summary>
        /// Exporta logs a CSV
        /// </summary>
        [HttpGet]
        [RequierePermiso("Ver Logs Sistema,ADMIN_LOGS")]
        public IActionResult Exportar(
            DateTime? fechaDesde,
            DateTime? fechaHasta,
            string modulo,
            string tipoAccion)
        {
            if (!fechaDesde.HasValue)
                fechaDesde = DateTime.Now.AddDays(-30);
            if (!fechaHasta.HasValue)
                fechaHasta = DateTime.Now.AddDays(1);

            var logs = _manejadorLogs.ConsultarLogs(
                fechaDesde,
                fechaHasta,
                modulo,
                tipoAccion,
                null,
                null,
                1,
                10000 // Máximo para exportación
            );

            // Generar CSV
            var csv = new StringBuilder();
            csv.AppendLine("Fecha,Hora,Usuario,Modulo,Accion,Entidad,ID Entidad,Resultado,IP,Error");

            foreach (var log in logs.Items)
            {
                csv.AppendLine(
                    $"{log.FechaRegistro:yyyy-MM-dd}," +
                    $"{log.FechaRegistro:HH:mm:ss}," +
                    $"\"{EscaparCsv(log.NombreUsuario)}\"," +
                    $"{log.Modulo}," +
                    $"{log.TipoAccion}," +
                    $"\"{EscaparCsv(log.EntidadDescripcion)}\"," +
                    $"{log.EntidadId}," +
                    $"{log.Resultado}," +
                    $"{log.IpCliente}," +
                    $"\"{EscaparCsv(log.MensajeError)}\""
                );
            }

            var bytes = Encoding.UTF8.GetBytes(csv.ToString());
            return File(bytes, "text/csv", $"logs_sistema_{DateTime.Now:yyyyMMdd_HHmmss}.csv");
        }

        private string EscaparCsv(string? valor)
        {
            if (string.IsNullOrEmpty(valor))
                return "";
            return valor.Replace("\"", "\"\"").Replace("\n", " ").Replace("\r", "");
        }
    }
}
