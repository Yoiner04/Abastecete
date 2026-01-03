using BusinessLogic;
using BusinessLogic.Interfaces;
using BusinessLogic.Models;
using BusinessLogic.Utilidades;
using Microsoft.AspNetCore.Mvc;

namespace Abastecete.Controllers
{
    public class AddonsController : Controller
    {
        private readonly IManejadorAddons _manejadorAddons;
        private readonly IManejadorAddonsAdmin _manejadorAddonsAdmin;
        private readonly IConfiguration _configuration;

        public AddonsController(
            IConfiguration configuration,
            IManejadorAddons manejadorAddons,
            IManejadorAddonsAdmin manejadorAddonsAdmin)
        {
            _configuration = configuration;
            _manejadorAddons = manejadorAddons;
            _manejadorAddonsAdmin = manejadorAddonsAdmin;
        }

        #region Admin - Gestión de Addons

        /// <summary>
        /// Vista principal CRUD de addons (Admin)
        /// </summary>
        [RequierePermiso("ADMIN_ADDONS,Ver Dashboard Admin")]
        public IActionResult Index()
        {
            var addons = _manejadorAddons.ObtenerAddonsDisponibles();
            return View(addons);
        }

        /// <summary>
        /// Obtiene un addon por ID (AJAX)
        /// </summary>
        [HttpGet]
        [RequierePermiso("ADMIN_ADDONS,Ver Dashboard Admin")]
        public IActionResult ObtenerAddon(int id)
        {
            try
            {
                var addons = _manejadorAddons.ObtenerAddonsDisponibles();
                var addon = addons.FirstOrDefault(a => a.Id == id);

                if (addon == null)
                    return NotFound(new { success = false, mensaje = "Addon no encontrado" });

                return Json(new
                {
                    success = true,
                    addon = new
                    {
                        id = addon.Id,
                        codigo = addon.Codigo,
                        nombre = addon.Nombre,
                        descripcion = addon.Descripcion,
                        tipoLimite = addon.TipoLimite,
                        cantidad = addon.Cantidad,
                        precio = addon.Precio,
                        icono = addon.Icono,
                        estado = addon.Estado
                    }
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al obtener addon: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al obtener addon" });
            }
        }

        /// <summary>
        /// Crear nuevo addon (Admin)
        /// </summary>
        [HttpPost]
        [RequierePermiso("ADMIN_ADDONS,Ver Dashboard Admin")]
        public IActionResult CrearAddon([FromBody] AddonTipo addon)
        {
            try
            {
                if (string.IsNullOrEmpty(addon.Codigo) || string.IsNullOrEmpty(addon.Nombre))
                {
                    return BadRequest(new { success = false, mensaje = "Código y nombre son requeridos" });
                }

                var resultado = _manejadorAddonsAdmin.CrearAddon(addon);

                if (resultado > 0)
                {
                    return Json(new { success = true, mensaje = "Addon creado exitosamente", id = resultado });
                }

                return BadRequest(new { success = false, mensaje = "No se pudo crear el addon" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al crear addon: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al crear addon" });
            }
        }

        /// <summary>
        /// Actualizar addon existente (Admin)
        /// </summary>
        [HttpPost]
        [RequierePermiso("ADMIN_ADDONS,Ver Dashboard Admin")]
        public IActionResult ActualizarAddon([FromBody] AddonTipo addon)
        {
            try
            {
                if (addon.Id <= 0)
                {
                    return BadRequest(new { success = false, mensaje = "ID de addon inválido" });
                }

                var resultado = _manejadorAddonsAdmin.ActualizarAddon(addon);

                if (resultado)
                {
                    return Json(new { success = true, mensaje = "Addon actualizado exitosamente" });
                }

                return BadRequest(new { success = false, mensaje = "No se pudo actualizar el addon" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al actualizar addon: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al actualizar addon" });
            }
        }

        /// <summary>
        /// Cambiar estado de addon (activar/desactivar)
        /// </summary>
        [HttpPost]
        [RequierePermiso("ADMIN_ADDONS,Ver Dashboard Admin")]
        public IActionResult CambiarEstado(int id, bool estado)
        {
            try
            {
                var resultado = _manejadorAddonsAdmin.CambiarEstadoAddon(id, estado);

                if (resultado)
                {
                    return Json(new { success = true, mensaje = estado ? "Addon activado" : "Addon desactivado" });
                }

                return BadRequest(new { success = false, mensaje = "No se pudo cambiar el estado" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al cambiar estado: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al cambiar estado" });
            }
        }

        #endregion

        #region Usuario - Compra de Addons

        /// <summary>
        /// Vista de tienda de addons para usuarios
        /// </summary>
        public IActionResult Tienda()
        {
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            if (usuarioId == null)
            {
                return RedirectToAction("Index", "Login");
            }

            var idLocal = HttpContext.Session.GetInt32("idLocal");
            if (idLocal == null || idLocal <= 0)
            {
                TempData["Error"] = "Necesitas tener un negocio registrado para comprar addons";
                return RedirectToAction("Crear", "Negocios");
            }

            var addonsDisponibles = _manejadorAddons.ObtenerAddonsDisponibles();
            var addonsComprados = _manejadorAddons.ObtenerAddonsLocal(idLocal.Value);
            var addonsAgrupados = addonsDisponibles.GroupBy(a => a.TipoLimite).ToDictionary(g => g.Key, g => g.ToList());

            ViewBag.AddonsComprados = addonsComprados;
            ViewBag.IdLocal = idLocal.Value;
            ViewBag.EpaycoPublicKey = _configuration["Epayco:PublicKey"];

            return View(addonsAgrupados);
        }

        /// <summary>
        /// Obtiene los addons comprados por el usuario actual
        /// </summary>
        [HttpGet]
        public IActionResult MisAddons()
        {
            var idLocal = HttpContext.Session.GetInt32("idLocal");
            if (idLocal == null || idLocal <= 0)
            {
                return Json(new { success = false, mensaje = "No tienes un negocio registrado" });
            }

            var addons = _manejadorAddons.ObtenerAddonsLocal(idLocal.Value);
            return Json(new
            {
                success = true,
                addons = addons.Select(a => new
                {
                    id = a.Id,
                    nombre = a.NombreAddon,
                    tipoLimite = a.TipoLimite,
                    cantidadComprada = a.CantidadComprada,
                    totalAgregado = a.TotalAgregado,
                    fechaCompra = a.FechaCompra.ToString("dd/MM/yyyy"),
                    fechaExpiracion = a.FechaExpiracion?.ToString("dd/MM/yyyy") ?? "No expira"
                })
            });
        }

        /// <summary>
        /// Inicia el proceso de compra de un addon
        /// </summary>
        [HttpPost]
        public IActionResult IniciarCompra([FromBody] CompraAddonRequest request)
        {
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            var idLocal = HttpContext.Session.GetInt32("idLocal");

            if (usuarioId == null || idLocal == null || idLocal <= 0)
            {
                return Json(new { success = false, mensaje = "Sesión inválida" });
            }

            try
            {
                var addons = _manejadorAddons.ObtenerAddonsDisponibles();
                var addon = addons.FirstOrDefault(a => a.Id == request.IdAddon);

                if (addon == null)
                {
                    return Json(new { success = false, mensaje = "Addon no encontrado" });
                }

                var total = addon.Precio * request.Cantidad;

                // Retornar datos para ePayco
                return Json(new
                {
                    success = true,
                    addon = new
                    {
                        id = addon.Id,
                        nombre = addon.Nombre,
                        precio = addon.Precio,
                        cantidad = request.Cantidad,
                        total = total
                    },
                    idLocal = idLocal.Value
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al iniciar compra: {ex.Message}");
                return Json(new { success = false, mensaje = "Error al procesar la solicitud" });
            }
        }

        /// <summary>
        /// Confirma la compra después del pago exitoso (POST - API)
        /// </summary>
        [HttpPost]
        public IActionResult ConfirmarCompra([FromBody] ConfirmacionCompraAddon request)
        {
            var idLocal = HttpContext.Session.GetInt32("idLocal");

            if (idLocal == null || idLocal <= 0)
            {
                return Json(new { success = false, mensaje = "Sesión inválida" });
            }

            try
            {
                var idCompra = _manejadorAddons.RegistrarCompraAddon(
                    idLocal.Value,
                    request.IdAddon,
                    request.Cantidad,
                    request.RefPago,
                    request.FechaExpiracion
                );

                if (idCompra > 0)
                {
                    return Json(new { success = true, mensaje = "Addon adquirido exitosamente", idCompra = idCompra });
                }

                return Json(new { success = false, mensaje = "No se pudo registrar la compra" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al confirmar compra: {ex.Message}");
                return Json(new { success = false, mensaje = "Error al confirmar la compra" });
            }
        }

        /// <summary>
        /// Callback de ePayco después del pago (GET - Redirect)
        /// </summary>
        [HttpGet]
        public IActionResult ConfirmarCompraAddon(int idAddon, int cantidad, string? ref_payco)
        {
            var idLocal = HttpContext.Session.GetInt32("idLocal");

            if (idLocal == null || idLocal <= 0)
            {
                TempData["Error"] = "Sesión inválida. Por favor inicia sesión nuevamente.";
                return RedirectToAction("Index", "Login");
            }

            try
            {
                // Verificar si el pago fue exitoso (ref_payco no está vacío)
                if (string.IsNullOrEmpty(ref_payco))
                {
                    TempData["Error"] = "No se recibió confirmación del pago.";
                    return RedirectToAction("Tienda");
                }

                // Registrar la compra del addon
                var idCompra = _manejadorAddons.RegistrarCompraAddon(
                    idLocal.Value,
                    idAddon,
                    cantidad,
                    ref_payco,
                    null // Sin fecha de expiración por defecto
                );

                if (idCompra > 0)
                {
                    TempData["Success"] = "¡Addon adquirido exitosamente! Ya puedes disfrutar de tus nuevos beneficios.";
                }
                else
                {
                    TempData["Error"] = "Hubo un problema al registrar tu compra. Contacta a soporte con la referencia: " + ref_payco;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al confirmar compra addon: {ex.Message}");
                TempData["Error"] = "Error al procesar la compra. Contacta a soporte.";
            }

            return RedirectToAction("Tienda");
        }

        #endregion
    }

    #region Request Models

    public class CompraAddonRequest
    {
        public int IdAddon { get; set; }
        public int Cantidad { get; set; } = 1;
    }

    public class ConfirmacionCompraAddon
    {
        public int IdAddon { get; set; }
        public int Cantidad { get; set; }
        public string RefPago { get; set; } = "";
        public DateTime? FechaExpiracion { get; set; }
    }

    #endregion
}
