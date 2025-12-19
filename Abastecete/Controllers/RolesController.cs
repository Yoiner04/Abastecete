using BusinessLogic;
using BusinessLogic.Models;
using BusinessLogic.Utilidades;
using Microsoft.AspNetCore.Mvc;

namespace ConnectionProject.Controllers
{
    public class RolesController : Controller
    {
        ManejadorUsuario manejadorU = new ManejadorUsuario();
        ManejadorPermisos manejadorP = new ManejadorPermisos();
        ManejadorRoles manejadorR = new ManejadorRoles();

        [RequierePermiso("Administrar Roles")]
        public IActionResult Consultar([FromQuery] int idRol=0)
        {
            ViewBag.idRol = idRol;
            ViewBag.administrar = RolPermisos.TienePermiso("Administrar Roles", HttpContext.Session.GetString("permisos"));
            List<Usuario> usuarios = manejadorU.ConsultarUsuarios(0);
            List<Permiso> permisos = manejadorP.ObtenerPermisos(idRol);
            List<Rol> roles = manejadorR.ObtenerRoles();
            ViewBag.usuarios = usuarios;
            ViewBag.permisos = permisos;
            ViewBag.roles = roles;
            ViewBag.rol = LoginController.rol;
            return View();
        }

        public IActionResult Registrar()
        {
            return View();
        }

        [HttpPost]
        [RequierePermiso("Administrar Roles")]
        public IActionResult CrearRol(Rol rol)
        {
            bool result = manejadorR.CrearRol(rol);
            return RedirectToAction("Consultar");
        }

        [RequierePermiso("Administrar Roles")]
        public IActionResult AsignarPermisoRol([FromQuery] int idRol, [FromQuery] int idPermiso)
        {
            bool result = manejadorP.AsignarPermiso(idRol, idPermiso);
            return RedirectToAction("Consultar", new { idRol = idRol });
        }

        [HttpPost]
        [RequierePermiso("Administrar Roles")]
        public IActionResult AsignarRol(PermisosViewModel e)
        {
            bool result = manejadorR.AsignarRol(e.Rol.Id, e.Usuario.Id);
            return RedirectToAction("Consultar");
        }
    }
}
