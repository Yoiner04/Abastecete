using BusinessLogic;
using BusinessLogic.Models;
using BusinessLogic.Utilidades;
using ConnectionProject.Controllers;
using Microsoft.AspNetCore.Mvc;

namespace Abastecete.Controllers
{
    public class UsuariosController : Controller
    {
        ManejadorUsuario manejadorU = new ManejadorUsuario();
        ManejadorTipoDocumento TipoDocumento = new ManejadorTipoDocumento();
        ManejadorSuscripciones manejadorSuscripciones = new ManejadorSuscripciones();
        ManejadorMembresias manejadorMembresias = new ManejadorMembresias();

        public UsuariosController()
        {

        }

        [RequierePermiso("Administrar Usuarios")]
        public IActionResult Consultar(int pagina = 1, int registrosPorPagina = 10, string busqueda = null)
        {
            ViewBag.rol = LoginController.rol;
            ViewBag.administrar = RolPermisos.TienePermiso("Administrar Usuarios", HttpContext.Session.GetString("permisos"));

            // Usar paginación para evitar traer todos los registros
            var resultado = manejadorU.ConsultarUsuariosPaginado(pagina, registrosPorPagina, busqueda);

            ViewBag.Busqueda = busqueda;

            return View(resultado);
        }

        public class EditarEstadoRequest
        {
            public int IdUsuario { get; set; }
            public int NuevoEstado { get; set; }
        }

        public class ExtenderMembresiaRequest
        {
            public int IdLocal { get; set; }
            public int IdSuscripcion { get; set; }
            public string Periodo { get; set; }
            public string Notas { get; set; }
        }

        public class CambiarMembresiaRequest
        {
            public int IdLocal { get; set; }
            public int IdTipoMembresia { get; set; }
            public string Periodo { get; set; }
        }

        [HttpPost]
        [RequierePermiso("Administrar Usuarios")]
        [Auditar(ModulosAuditoria.USUARIOS, TiposAccionAuditoria.UPDATE)]
        public IActionResult EditarEstado([FromBody] EditarEstadoRequest data)
        {
            try
            {

                bool resultado = manejadorU.EditarEstadoUsuario(data.IdUsuario, data.NuevoEstado);

                if (resultado)
                {
                    return Json(new { mensaje = "Estado actualizado correctamente." });
                }
                else
                {
                    return Json(new { mensaje = "Error al actualizar el estado en la BD." });
                }
            }
            catch (Exception ex)
            {
                return Json(new { mensaje = $"Error interno en el servidor: {ex.Message}" });
            }
        }

        [HttpPost]
        [RequierePermiso("Administrar Usuarios")]
        [Auditar(ModulosAuditoria.MEMBRESIAS, TiposAccionAuditoria.UPDATE)]
        public IActionResult ExtenderMembresia([FromBody] ExtenderMembresiaRequest data)
        {
            try
            {
                // Calcular el monto según el período (0 porque es extensión manual del admin)
                decimal monto = 0;

                var resultado = manejadorSuscripciones.RenovarSuscripcion(
                    data.IdSuscripcion,
                    data.Periodo,
                    monto,
                    "Admin - Extensión Manual"
                );

                if (resultado.IdSuscripcion > 0)
                {
                    return Json(new
                    {
                        success = true,
                        mensaje = $"Membresía extendida exitosamente. Nueva fecha de vencimiento: {resultado.NuevaFechaFin:dd/MM/yyyy}",
                        nuevaFechaFin = resultado.NuevaFechaFin.ToString("dd/MM/yyyy")
                    });
                }
                else
                {
                    return Json(new { success = false, mensaje = "Error al extender la membresía." });
                }
            }
            catch (Exception ex)
            {
                return Json(new { success = false, mensaje = $"Error: {ex.Message}" });
            }
        }

        [HttpGet]
        [RequierePermiso("Administrar Usuarios")]
        public IActionResult ObtenerInfoSuscripcion(int idLocal)
        {
            try
            {
                var suscripcion = manejadorSuscripciones.ObtenerSuscripcionActiva(idLocal);

                if (suscripcion != null)
                {
                    return Json(new
                    {
                        success = true,
                        suscripcion = new
                        {
                            id = suscripcion.Id,
                            tipoMembresiaId = suscripcion.TipoMembresia?.Id,
                            tipoMembresia = suscripcion.TipoMembresia?.Nombre,
                            fechaInicio = suscripcion.FechaInicio.ToString("dd/MM/yyyy"),
                            fechaFin = suscripcion.FechaFin.ToString("dd/MM/yyyy"),
                            diasRestantes = suscripcion.DiasRestantes,
                            estado = suscripcion.EstadoDescripcion
                        }
                    });
                }
                else
                {
                    return Json(new { success = false, mensaje = "No se encontró suscripción activa." });
                }
            }
            catch (Exception ex)
            {
                return Json(new { success = false, mensaje = $"Error: {ex.Message}" });
            }
        }

        [HttpPost]
        [RequierePermiso("Administrar Usuarios")]
        [Auditar(ModulosAuditoria.MEMBRESIAS, TiposAccionAuditoria.UPDATE)]
        public IActionResult CambiarMembresia([FromBody] CambiarMembresiaRequest data)
        {
            try
            {
                // Crear nueva suscripción con el nuevo tipo de membresía
                var resultado = manejadorSuscripciones.CrearSuscripcion(
                    data.IdLocal,
                    data.IdTipoMembresia,
                    data.Periodo,
                    0, // Monto 0 porque es cambio manual del admin
                    "Admin - Cambio Manual",
                    "Cambio de membresía desde panel de administración"
                );

                if (resultado.IdSuscripcion > 0)
                {
                    var membresia = manejadorMembresias.ObtenerMembresia(data.IdTipoMembresia);
                    return Json(new
                    {
                        success = true,
                        mensaje = $"Membresía cambiada a {membresia?.Nombre ?? "nueva membresía"} exitosamente.",
                        tipoCambio = resultado.TipoCambio
                    });
                }
                else
                {
                    return Json(new { success = false, mensaje = "Error al cambiar la membresía." });
                }
            }
            catch (Exception ex)
            {
                return Json(new { success = false, mensaje = $"Error: {ex.Message}" });
            }
        }

        [HttpGet]
        [RequierePermiso("Administrar Usuarios")]
        public IActionResult ObtenerTiposMembresia()
        {
            try
            {
                // Obtener TODAS las membresías activas directamente
                var todasMembresias = manejadorMembresias.ObtenerTodasMembresias();
                var membresias = todasMembresias.Select(m => new
                {
                    id = m.Id,
                    nombre = m.Nombre,
                    costoMensual = m.Costo,
                    costoTrimestral = m.Costo_trimestral,
                    costoSemestral = m.Costo_semestral,
                    costoAnual = m.Costo_anual
                }).ToList();

                return Json(new { success = true, membresias });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, mensaje = $"Error: {ex.Message}" });
            }
        }

        public IActionResult Registrar()
        {
            List<TipoDocumento> tiposDocumento = TipoDocumento.ObtenerTipoDocumentos();
            ViewBag.TiposDocumento = tiposDocumento;
            return View();
        }

        public IActionResult Actualizar()
        {
            var idUsuario = HttpContext.Session.GetInt32("idUsuario");

            if (idUsuario == null)
            {
                return RedirectToAction("Login", "Login"); // Redirigir al login si no hay usuario autenticado
            }

            Usuario usuario = manejadorU.ObtenerUsuarios(idUsuario.Value).FirstOrDefault();

            //if (usuario == null)
            //{
            //    return RedirectToAction("Login", "Login"); // Redirigir si el usuario no existe
            //}

            List<TipoDocumento> tiposDocumento = TipoDocumento.ObtenerTipoDocumentos();
            ViewBag.TiposDocumento = tiposDocumento;

            return View(usuario);
        }

        [HttpPost]
        public IActionResult EditarUsuario(Usuario usuario)
        {
            Persona persona = usuario.Persona;
            persona.Correo = usuario.Correo;
            bool resultado = manejadorU.EditarUsuario(persona);

            if (resultado)
            {
                TempData["mensaje"] = "¡Tu información ha sido actualizada correctamente!";
                TempData["tipo"] = "success";
            }
            else
            {
                TempData["mensaje"] = "Hubo un error al actualizar la información.";
                TempData["tipo"] = "danger";
            }

            return RedirectToAction("Actualizar", "Usuarios");
        }

        [HttpPost]
        public IActionResult Registrar(Usuario usuario)
        {
            Console.WriteLine("=== DEBUG REGISTRO ===");
            Console.WriteLine($"Persona null: {usuario?.Persona == null}");
            Console.WriteLine($"Nombre: {usuario?.Persona?.Nombre}");
            Console.WriteLine($"Apellido: {usuario?.Persona?.Apellido}");
            Console.WriteLine($"Documento: {usuario?.Persona?.Documento}");
            Console.WriteLine($"TipoDoc null: {usuario?.Persona?.TipoDeDocumento == null}");
            Console.WriteLine($"TipoDoc.Id: {usuario?.Persona?.TipoDeDocumento?.Id}");
            Console.WriteLine($"Telefono: {usuario?.Persona?.Telefono}");
            Console.WriteLine($"Correo: {usuario?.Correo}");
            Console.WriteLine($"Contrasenia: {usuario?.Contrasenia?.Length} chars");
            Console.WriteLine($"CodigoReferido: {usuario?.CodigoReferido}");
            Console.WriteLine("======================");

            bool result = manejadorU.RegistrarUsuario(usuario);

            if (result)
            {
                return RedirectToAction("Login", "Login");
            }
            else
            {
                ModelState.AddModelError("", "No se pudo registrar el usuario. Intente nuevamente.");
                return View(usuario);
            }
        }

    }
}