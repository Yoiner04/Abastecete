using BusinessLogic;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using System.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Google;
using System.Security.Claims;
using System.Text.RegularExpressions;

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
            // Evitar que el usuario regrese con la flecha "Atrás" después de cerrar sesión
            Response.Headers["Cache-Control"] = "no-cache, no-store, must-revalidate";
            Response.Headers["Pragma"] = "no-cache";
            Response.Headers["Expires"] = "0";

            return View();
        }

        [HttpPost]
        public IActionResult Login(Usuario usuario)
        {
            ManejadorUsuario manejador = new ManejadorUsuario();
            DataTable data = manejador.Login(usuario.Correo, usuario.Contrasenia);

            if (data.Rows.Count > 0)
            {
                int idRol = Convert.ToInt32(data.Rows[0]["FK_ID_ROL"]);

                // Evita contar intentos fallidos si el error ya está en la sesión
                if (HttpContext.Session.GetString("LastLoginError") == usuario.Correo)
                {
                    TempData["Error"] = "Contraseña incorrecta. Si fallas 5 veces, tu cuenta será bloqueada.";
                    return View(usuario);
                }

                switch (idRol)
                {
                    case 97:
                        TempData["Error"] = "Tu cuenta ha sido inhabilitada.";
                        return View(usuario);
                    case 98:
                        TempData["Error"] = "Correo electrónico no válido.";
                        return View(usuario);
                    case 99:
                        TempData["Error"] = "Contraseña incorrecta. Si fallas 5 veces, tu cuenta será bloqueada.";
                        HttpContext.Session.SetString("LastLoginError", usuario.Correo); // Guarda el error en la sesión
                        return View(usuario);
                    case 0:
                        TempData["Error"] = "Tu cuenta ha sido bloqueada por demasiados intentos fallidos. Inténtalo en una hora.";
                        return View(usuario);
                    default:
                        // Limpiar sesión de errores previos
                        HttpContext.Session.Remove("LastLoginError");

                        // Guardar sesión y permisos
                        GuardarPermisosRol(idRol);
                        return Redirect("~/Home/Principal");
                }
            }

            TempData["Error"] = "Credenciales incorrectas.";
            return View(usuario);
        }

        public IActionResult Logout()
        {
            HttpContext.Session.Clear();

            // Eliminar cookies de autenticación
            Response.Cookies.Delete(".AspNetCore.Session");
            Response.Cookies.Delete(".AspNetCore.Cookies");

            // Cerrar sesión de autenticación en Google
            HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);

            // Evitar que el usuario pueda volver atrás en el navegador
            Response.Headers["Cache-Control"] = "no-cache, no-store, must-revalidate";
            Response.Headers["Pragma"] = "no-cache";
            Response.Headers["Expires"] = "0";

            return RedirectToAction("Login");
        }

        private void GuardarPermisosRol(int idRol)
        {
            ManejadorPermisos manejadorP = new ManejadorPermisos();
            HttpContext.Session.SetString("idRol", idRol.ToString());

            Dictionary<string, bool> permisos = manejadorP.ObtenerPermisos(idRol)
                .ToDictionary(c => c.Nombre, c => c.Estado);

            HttpContext.Session.SetString("permisos", JsonConvert.SerializeObject(permisos));
        }

        // Redirigir a Google para el login
        public IActionResult LoginWithGoogle()
        {
            HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);

            var properties = new AuthenticationProperties
            {
                RedirectUri = Url.Action("GoogleResponse"),
                IsPersistent = false,
                AllowRefresh = true
            };

            // 🔹 Forzar que Google siempre pida la cuenta al iniciar sesión
            properties.Items["prompt"] = "select_account";
            return Challenge(properties, GoogleDefaults.AuthenticationScheme);
        }
        private bool EsCorreoValido(string correo)
        {
            return Regex.IsMatch(correo, @"^[^@\s]+@[^@\s]+\.[^@\s]+$");
        }

        // Manejar la respuesta de Google
        public async Task<IActionResult> GoogleResponse()
        {
            try
            {
                var result = await HttpContext.AuthenticateAsync(CookieAuthenticationDefaults.AuthenticationScheme);

                if (!result.Succeeded)
                {
                    TempData["Error"] = "Error al autenticar con Google.";
                    return RedirectToAction("Login");
                }

                var claims = result.Principal.Identities.FirstOrDefault()?.Claims.Select(claim => new
                {
                    claim.Type,
                    claim.Value
                }).ToList();

                string email = claims.FirstOrDefault(c => c.Type == ClaimTypes.Email)?.Value;
                string name = claims.FirstOrDefault(c => c.Type == ClaimTypes.Name)?.Value;

                if (!EsCorreoValido(email))
                {
                    TempData["Error"] = "El correo proporcionado no es válido.";
                    return RedirectToAction("Login");
                }

                ManejadorUsuario manejador = new ManejadorUsuario();
                DataTable data = manejador.LoginGoogle(email);

                int rol = data.Rows.Count > 0 ? Convert.ToInt32(data.Rows[0]["FK_ID_ROL"]) : 0;

                // Si el usuario NO está registrado (FK_ID_ROL = 0), se registra automáticamente
                if (rol == 0)
                {
                    int userId = manejador.RegistrarUsuarioGoogle(email, name);
                    if (userId == 0)
                    {
                        TempData["Error"] = "Hubo un problema al registrar tu cuenta con Google.";
                        return RedirectToAction("Login");
                    }

                    // Volver a obtener el rol después del registro
                    data = manejador.LoginGoogle(email);
                    if (data.Rows.Count > 0)
                    {
                        rol = Convert.ToInt32(data.Rows[0]["FK_ID_ROL"]);
                    }
                }

                // 🔹 Guardar en sesión los datos del usuario
                HttpContext.Session.SetString("userEmail", email);
                HttpContext.Session.SetString("userName", name);
                HttpContext.Session.SetInt32("userRol", rol);

                // 🔹 Configurar permisos
                GuardarPermisosRol(rol);

                return Redirect("~/Home/Principal");
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Hubo un error en el inicio de sesión.";
                return RedirectToAction("Login");
            }
        }

        public IActionResult RecuperarContrasenia()
        {
            return View();
        }

        public IActionResult IngresarNuevaContrasenia()
        {
            return View();
        }
    }
}