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
            bool result = manejadorU.RegistrarUsuario(usuario);
            return RedirectToAction("Registrar");
        }

        //[HttpPost]
        //public IActionResult Registrar(Usuario usuario)
        //{
        //    bool result = manejadorU.RegistrarUsuario(usuario);
        //    return RedirectToAction("Registrar");
        //}
    }
}
