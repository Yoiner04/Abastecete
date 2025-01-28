using BusinessLogic;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using System.Data;

namespace ConnectionProject.Controllers
{
    public class LoginController : Controller
    {
        public static int rol = 0;

        public LoginController()
        {
        }
        public IActionResult Login()
        {
            return View();
        }

        [HttpPost]
        public IActionResult Login(Usuario usuario)
        {
            ManejadorUsuario manejador = new ManejadorUsuario();
            
            DataTable data = manejador.Login(usuario.Correo, usuario.Contrasenia);
            if (data.Rows.Count > 0)
            {
                foreach (DataRow row in data.AsEnumerable())
                {
                    rol = int.Parse(row["FK_ID_ROL"].ToString());
                    GuardarPermisosRol(rol);
                }
                return Redirect("~/Home/Principal");
            }
            return View();
        }

        public IActionResult Logout()
        {
            HttpContext.Session.Clear();
            return RedirectToAction("Login");
        }


        private void GuardarPermisosRol(int idRol)
        {
            ManejadorPermisos manejadorP = new ManejadorPermisos();
            HttpContext.Session.SetString("idRol", rol.ToString());
            
            Dictionary<string, bool> permisos = manejadorP.ObtenerPermisos(rol).ToDictionary(c => c.Nombre, c => c.Estado);
            HttpContext.Session.SetString("permisos", JsonConvert.SerializeObject(permisos));
            var d = JsonConvert.DeserializeObject<Dictionary<string, bool>>(HttpContext.Session.GetString("permisos"));
        }
    }
}
