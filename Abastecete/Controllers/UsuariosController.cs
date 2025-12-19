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
        public IActionResult Consultar()
        {
            var idUsuario = HttpContext.Session.GetInt32("idUsuario");

            ViewBag.rol = LoginController.rol;
            ViewBag.administrar = RolPermisos.TienePermiso("Administrar Usuarios", HttpContext.Session.GetString("permisos"));

            // Si el usuario es administrador, obtiene todos los usuarios con sus locales y suscripciones
            var usuarios = manejadorU.ConsultarUsuariosConLocal(idUsuario == 2 ? 0 : idUsuario.Value);

            return View(usuarios);
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