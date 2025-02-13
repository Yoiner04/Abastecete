using BusinessLogic.Utilidades;
using ConnectionProject.Controllers;
using Microsoft.AspNetCore.Mvc;

namespace Abastecete.Controllers
{
    public class NegociosController : Controller
    {

        public IActionResult Index()
        {
            return View();
        }

        [HttpGet]
        public IActionResult Consultar()
        {
            //ViewBag.rol = LoginController.rol;
            //ViewBag.administrar = RolPermisos.TienePermiso("Administrar Proveedores", HttpContext.Session.GetString("permisos"));
            return View();
        }

    }
}
