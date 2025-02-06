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
        public IActionResult Consultar()
        {
            ViewBag.rol = LoginController.rol;
            ViewBag.administrar = RolPermisos.TienePermiso("Administrar Usuarios", HttpContext.Session.GetString("permisos"));

            ViewBag.usuarios = manejadorU.ObtenerUsuarios(0);
            return View();
        }
        public IActionResult Registrar()
        {
            return View();
        }

        [HttpPost]
        public IActionResult Registrar(Usuario usuario)
        {
            if (!ModelState.IsValid)
            {
                // Si hay errores de validación, vuelve a mostrar la vista con los mensajes
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



        //[HttpPost]
        //public IActionResult Registrar(Usuario usuario)
        //{
        //    bool result = manejadorU.RegistrarUsuario(usuario);
        //    return RedirectToAction("Registrar");
        //}
    }
}