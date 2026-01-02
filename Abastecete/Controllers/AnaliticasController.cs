using BusinessLogic;
using BusinessLogic.Models;
using BusinessLogic.Utilidades;
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;

namespace Abastecete.Controllers
{
    public class AnaliticasController : Controller
    {
        private readonly ManejadorAnaliticas manejadorAnaliticas = new ManejadorAnaliticas();
        private readonly ManejadorNegocios manejadorNegocios = new ManejadorNegocios();

        /// <summary>
        /// Dashboard de administrador - Estadísticas globales del sistema
        /// </summary>
        public IActionResult DashboardAdmin(string periodo = "7d")
        {
            var idUsuario = HttpContext.Session.GetInt32("idUsuario");
            var permisos = HttpContext.Session.GetString("permisosSistema") ?? "";

            if (idUsuario == null)
            {
                return RedirectToAction("Index", "Login");
            }

            // Verificar permiso ADMIN_DASHBOARD
            if (string.IsNullOrEmpty(permisos) || !RolPermisos.TienePermiso("ADMIN_DASHBOARD", permisos))
            {
                TempData["mensaje"] = "No tienes permisos para acceder a esta sección.";
                TempData["tipo"] = "error";
                return RedirectToAction("Principal", "Home");
            }

            // Calcular rango de fechas según el período
            var (fechaInicio, fechaFin) = CalcularRangoFechas(periodo);

            var dashboard = manejadorAnaliticas.ObtenerDashboardAdmin(fechaInicio, fechaFin);

            ViewBag.PeriodoSeleccionado = periodo;

            return View(dashboard);
        }

        /// <summary>
        /// API para obtener datos del dashboard admin (para actualización AJAX)
        /// </summary>
        [HttpGet]
        public IActionResult ObtenerDatosAdmin(string periodo = "7d")
        {
            var idUsuario = HttpContext.Session.GetInt32("idUsuario");
            if (idUsuario == null)
            {
                return Json(new { success = false, mensaje = "Sesión expirada" });
            }

            var permisos = HttpContext.Session.GetString("permisosSistema") ?? "";
            if (string.IsNullOrEmpty(permisos) || !RolPermisos.TienePermiso("ADMIN_DASHBOARD", permisos))
            {
                return Json(new { success = false, mensaje = "Sin permisos" });
            }

            var (fechaInicio, fechaFin) = CalcularRangoFechas(periodo);
            var dashboard = manejadorAnaliticas.ObtenerDashboardAdmin(fechaInicio, fechaFin);

            return Json(new
            {
                success = true,
                estadisticas = new
                {
                    totalLocalesActivos = dashboard.Estadisticas.TotalLocalesActivos,
                    totalUsuariosActivos = dashboard.Estadisticas.TotalUsuariosActivos,
                    nuevosUsuariosPeriodo = dashboard.Estadisticas.NuevosUsuariosPeriodo,
                    nuevosLocalesPeriodo = dashboard.Estadisticas.NuevosLocalesPeriodo,
                    totalVisitasLocales = dashboard.Estadisticas.TotalVisitasLocales,
                    totalClicsWhatsapp = dashboard.Estadisticas.TotalClicsWhatsapp,
                    totalProductosActivos = dashboard.Estadisticas.TotalProductosActivos,
                    cambioVisitas = dashboard.Estadisticas.CambioVisitas,
                    cambioWhatsapp = dashboard.Estadisticas.CambioWhatsapp,
                    cambioNuevosUsuarios = dashboard.Estadisticas.CambioNuevosUsuarios,
                    cambioNuevosLocales = dashboard.Estadisticas.CambioNuevosLocales
                },
                datosGrafico = dashboard.DatosGrafico.Select(d => new
                {
                    fecha = d.Fecha.ToString("yyyy-MM-dd"),
                    fechaCorta = d.Fecha.ToString("dd MMM"),
                    visitas = d.Visitas,
                    clicsWhatsapp = d.ClicsWhatsapp,
                    nuevosUsuarios = d.NuevosUsuarios,
                    nuevosLocales = d.NuevosLocales
                }),
                distribucionMembresias = dashboard.DistribucionMembresias.Select(m => new
                {
                    nombre = m.NombreMembresia,
                    activas = m.Activas,
                    pendientes = m.Pendientes,
                    vencidas = m.Vencidas
                }),
                localesMasVisitados = dashboard.LocalesMasVisitados.Select(l => new
                {
                    id = l.IdLocal,
                    nombre = l.NombreLocal,
                    logo = l.LogoUrl,
                    visitas = l.TotalVisitas
                })
            });
        }

        /// <summary>
        /// Dashboard de analíticas para el local del usuario actual
        /// </summary>
        public IActionResult Index(string periodo = "7d")
        {
            var idUsuario = HttpContext.Session.GetInt32("idUsuario");
            if (idUsuario == null)
            {
                return RedirectToAction("Index", "Login");
            }

            // Obtener el local del usuario
            var local = manejadorNegocios.ConsultarNegocioPorUsuario(idUsuario.Value);
            if (local == null)
            {
                TempData["mensaje"] = "No tienes un local registrado.";
                TempData["tipo"] = "warning";
                return RedirectToAction("Principal", "Home");
            }

            // Calcular rango de fechas según el período
            var (fechaInicio, fechaFin) = CalcularRangoFechas(periodo);

            var dashboard = manejadorAnaliticas.ObtenerDashboard(local.Id, fechaInicio, fechaFin);

            ViewBag.Local = local;
            ViewBag.PeriodoSeleccionado = periodo;

            return View(dashboard);
        }

        /// <summary>
        /// API para obtener datos del dashboard (para actualización AJAX)
        /// </summary>
        [HttpGet]
        public IActionResult ObtenerDatos(string periodo = "7d")
        {
            var idUsuario = HttpContext.Session.GetInt32("idUsuario");
            if (idUsuario == null)
            {
                return Json(new { success = false, mensaje = "Sesión expirada" });
            }

            var local = manejadorNegocios.ConsultarNegocioPorUsuario(idUsuario.Value);
            if (local == null)
            {
                return Json(new { success = false, mensaje = "No tienes un local registrado" });
            }

            var (fechaInicio, fechaFin) = CalcularRangoFechas(periodo);
            var dashboard = manejadorAnaliticas.ObtenerDashboard(local.Id, fechaInicio, fechaFin);

            return Json(new
            {
                success = true,
                estadisticas = new
                {
                    totalVisitas = dashboard.Estadisticas.TotalVisitas,
                    totalClicsWhatsapp = dashboard.Estadisticas.TotalClicsWhatsapp,
                    totalVisitasProductos = dashboard.Estadisticas.TotalVisitasProductos,
                    totalAparicionesBusqueda = dashboard.Estadisticas.TotalAparicionesBusqueda,
                    cambioVisitas = dashboard.Estadisticas.CambioVisitas,
                    cambioClicsWhatsapp = dashboard.Estadisticas.CambioClicsWhatsapp,
                    cambioVisitasProductos = dashboard.Estadisticas.CambioVisitasProductos
                },
                datosGrafico = dashboard.DatosGrafico.Select(d => new
                {
                    fecha = d.Fecha.ToString("yyyy-MM-dd"),
                    fechaCorta = d.Fecha.ToString("dd MMM"),
                    visitas = d.Visitas,
                    clicsWhatsapp = d.ClicsWhatsapp,
                    visitasProductos = d.VisitasProductos
                }),
                productosMasVistos = dashboard.ProductosMasVistos.Select(p => new
                {
                    id = p.IdProducto,
                    nombre = p.NombreProducto,
                    imagen = p.ImagenUrl,
                    vistas = p.TotalVistas
                })
            });
        }

        /// <summary>
        /// Endpoint para registrar eventos (llamado desde JavaScript)
        /// </summary>
        [HttpPost]
        public IActionResult RegistrarEvento([FromBody] RegistrarEventoRequest request)
        {
            if (request == null || request.IdLocal <= 0)
            {
                return Json(new { success = false });
            }

            // Obtener información del visitante
            var ip = HttpContext.Connection.RemoteIpAddress?.ToString();
            var userAgent = Request.Headers["User-Agent"].ToString();
            var referrer = Request.Headers["Referer"].ToString();

            // Parsear tipo de evento
            if (!Enum.TryParse<TipoEventoAnalitica>(request.TipoEvento, out var tipoEvento))
            {
                return Json(new { success = false });
            }

            var resultado = manejadorAnaliticas.RegistrarEvento(
                request.IdLocal,
                tipoEvento,
                request.IdProducto,
                ip,
                userAgent,
                referrer
            );

            return Json(new { success = resultado });
        }

        private (DateTime fechaInicio, DateTime fechaFin) CalcularRangoFechas(string periodo)
        {
            var fechaFin = DateTime.Today;
            DateTime fechaInicio;

            switch (periodo)
            {
                case "today":
                    fechaInicio = DateTime.Today;
                    break;
                case "7d":
                    fechaInicio = fechaFin.AddDays(-6);
                    break;
                case "30d":
                    fechaInicio = fechaFin.AddDays(-29);
                    break;
                case "90d":
                    fechaInicio = fechaFin.AddDays(-89);
                    break;
                case "year":
                    fechaInicio = new DateTime(fechaFin.Year, 1, 1);
                    break;
                default:
                    fechaInicio = fechaFin.AddDays(-6);
                    break;
            }

            return (fechaInicio, fechaFin);
        }

        public class RegistrarEventoRequest
        {
            public int IdLocal { get; set; }
            public int? IdProducto { get; set; }
            public string TipoEvento { get; set; } = "";
            public string? Plataforma { get; set; } // facebook, twitter, whatsapp, copy_link
        }
    }
}
