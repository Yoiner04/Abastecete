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
        private readonly ManejadorUsuarios manejadorUsuarios;

        public UsuariosController()
        {
            manejadorUsuarios = new ManejadorUsuarios();
        }

        public IActionResult Consultar()
        {
            ViewBag.rol = LoginController.rol;
            ViewBag.administrar = RolPermisos.TienePermiso("Administrar Usuarios", HttpContext.Session.GetString("permisos"));

            List<Usuario> usuarios = manejadorUsuarios.ConsultarUsuarios();
            return View(usuarios);
        }

        public class EditarEstadoRequest
        {
            public int IdUsuario { get; set; }
            public int NuevoEstado { get; set; }
        }

        [HttpPost]
        public IActionResult EditarEstado([FromBody] EditarEstadoRequest data)
        {
            try
            {

                bool resultado = manejadorUsuarios.EditarEstadoUsuario(data.IdUsuario, data.NuevoEstado);

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
            return View();
        }

        public IActionResult Actualizar()
        {
            return View();
        }

        [HttpPost]
        public IActionResult Registrar(Usuario usuario)
        {
            if (!ModelState.IsValid)
            {
                return View(usuario);
            }

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