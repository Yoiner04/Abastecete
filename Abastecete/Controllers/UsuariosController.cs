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

        [HttpPost]
        [RequierePermiso("Administrar Usuarios")]
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