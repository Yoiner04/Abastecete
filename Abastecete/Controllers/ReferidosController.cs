using BusinessLogic;
using BusinessLogic.Models;
using BusinessLogic.Utilidades;
using Microsoft.AspNetCore.Mvc;

namespace Abastecete.Controllers
{
    public class ReferidosController : Controller
    {
        private readonly ManejadorReferidos manejadorReferidos;

        public ReferidosController()
        {
            manejadorReferidos = new ManejadorReferidos();
        }

        #region Configuración (Admin)

        /// <summary>
        /// Vista de configuración del sistema de referidos (admin)
        /// </summary>
        [RequierePermiso("ADMIN_REFERIDOS")]
        public IActionResult Configuracion()
        {
            var config = manejadorReferidos.ObtenerConfiguracion();
            return View(config);
        }

        /// <summary>
        /// Obtiene la configuración actual (AJAX)
        /// </summary>
        [HttpGet]
        [RequierePermiso("ADMIN_REFERIDOS")]
        public IActionResult ObtenerConfiguracion()
        {
            try
            {
                var config = manejadorReferidos.ObtenerConfiguracion();
                return Json(new
                {
                    success = true,
                    config = new
                    {
                        tipoDescuentoReferido = config.TipoDescuentoReferido,
                        valorDescuentoReferido = config.ValorDescuentoReferido,
                        tipoDescuentoDueno = config.TipoDescuentoDueno,
                        valorDescuentoDueno = config.ValorDescuentoDueno,
                        descuentoActivo = config.DescuentoActivo,
                        fechaActualizacion = config.FechaActualizacion
                    }
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al obtener configuración: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al obtener configuración" });
            }
        }

        /// <summary>
        /// Actualiza la configuración del sistema de referidos
        /// </summary>
        [HttpPost]
        [RequierePermiso("ADMIN_REFERIDOS")]
        [Auditar(ModulosAuditoria.USUARIOS, TiposAccionAuditoria.UPDATE)]
        public IActionResult ActualizarConfiguracion([FromBody] ConfiguracionReferidosRequest request)
        {
            try
            {
                int usuarioId = HttpContext.Session.GetInt32("idUser") ?? 0;

                var config = new ConfiguracionReferidos
                {
                    TipoDescuentoReferido = request.TipoDescuentoReferido,
                    ValorDescuentoReferido = request.ValorDescuentoReferido,
                    TipoDescuentoDueno = request.TipoDescuentoDueno,
                    ValorDescuentoDueno = request.ValorDescuentoDueno,
                    DescuentoActivo = request.DescuentoActivo,
                    LimiteUsosCodigo = request.LimiteUsosCodigo
                };

                bool resultado = manejadorReferidos.ActualizarConfiguracion(config, usuarioId);

                if (resultado)
                {
                    return Json(new { success = true, mensaje = "Configuración actualizada correctamente" });
                }

                return BadRequest(new { success = false, mensaje = "No se pudo actualizar la configuración" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al actualizar configuración: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al actualizar configuración" });
            }
        }

        #endregion

        #region Validación de Códigos (Público)

        /// <summary>
        /// Valida un código de referido (AJAX - usado en registro)
        /// </summary>
        [HttpGet]
        public IActionResult ValidarCodigo(string codigo)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(codigo))
                {
                    return Json(new { valido = false, mensaje = "Código vacío" });
                }

                int? idUsuarioActual = HttpContext.Session.GetInt32("idUser");
                var validacion = manejadorReferidos.ValidarCodigo(codigo.Trim(), idUsuarioActual);

                return Json(new
                {
                    valido = validacion.Valido,
                    mensaje = validacion.Mensaje,
                    nombreDueno = validacion.NombreDueno
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al validar código: {ex.Message}");
                return Json(new { valido = false, mensaje = "Error al validar código" });
            }
        }

        #endregion

        #region Panel de Negocio

        /// <summary>
        /// Vista de mis referidos (panel de negocio)
        /// </summary>
        public IActionResult MisReferidos()
        {
            int? idUsuario = HttpContext.Session.GetInt32("idUser");
            if (!idUsuario.HasValue)
            {
                return RedirectToAction("Login", "Login");
            }

            var resumen = manejadorReferidos.ObtenerResumen(idUsuario.Value);
            var referidos = manejadorReferidos.ObtenerMisReferidos(idUsuario.Value);

            ViewBag.Resumen = resumen;
            return View(referidos);
        }

        /// <summary>
        /// Obtiene el resumen de referidos (AJAX)
        /// </summary>
        [HttpGet]
        public IActionResult ObtenerResumen()
        {
            try
            {
                int? idUsuario = HttpContext.Session.GetInt32("idUser");
                if (!idUsuario.HasValue)
                {
                    return Unauthorized(new { success = false, mensaje = "No autenticado" });
                }

                var resumen = manejadorReferidos.ObtenerResumen(idUsuario.Value);

                return Json(new
                {
                    success = true,
                    resumen = new
                    {
                        codigoReferido = resumen.CodigoReferido,
                        totalReferidos = resumen.TotalReferidos,
                        referidosCompraron = resumen.ReferidosCompraron,
                        creditoTotalGanado = resumen.CreditoTotalGanado,
                        creditoDisponible = resumen.CreditoDisponible
                    }
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al obtener resumen: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al obtener resumen" });
            }
        }

        /// <summary>
        /// Calcula el descuento disponible para una compra (AJAX)
        /// </summary>
        [HttpGet]
        public IActionResult CalcularDescuento(decimal monto)
        {
            try
            {
                int? idUsuario = HttpContext.Session.GetInt32("idUser");
                if (!idUsuario.HasValue)
                {
                    return Json(new
                    {
                        success = true,
                        descuentoReferido = 0,
                        creditoDisponible = 0,
                        montoFinal = monto
                    });
                }

                var calculo = manejadorReferidos.CalcularDescuento(idUsuario.Value, monto);

                return Json(new
                {
                    success = true,
                    descuentoReferido = calculo.DescuentoReferido,
                    creditoDisponible = calculo.CreditoDisponible,
                    yaUsoDescuento = calculo.YaUsoDescuento,
                    codigoUsado = calculo.CodigoUsado,
                    tipoDescuento = calculo.TipoDescuento,
                    valorConfigurado = calculo.ValorConfigurado,
                    montoFinal = calculo.MontoFinal
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al calcular descuento: {ex.Message}");
                return Json(new
                {
                    success = false,
                    descuentoReferido = 0,
                    creditoDisponible = 0,
                    montoFinal = monto
                });
            }
        }

        #endregion

        #region Clases de Request

        public class ConfiguracionReferidosRequest
        {
            public string TipoDescuentoReferido { get; set; } = "";
            public decimal ValorDescuentoReferido { get; set; }
            public string TipoDescuentoDueno { get; set; } = "";
            public decimal ValorDescuentoDueno { get; set; }
            public bool DescuentoActivo { get; set; }
            public int LimiteUsosCodigo { get; set; } = 0;
        }

        #endregion
    }
}
