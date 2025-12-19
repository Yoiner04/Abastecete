using BusinessLogic;
using BusinessLogic.Models;
using BusinessLogic.Utilidades;
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
using Abastecete.Models;

namespace ConnectionProject.Controllers
{
    public class LoginController : Controller
    {
        private readonly ManejadorUsuario _manejadorUsuario;
        private readonly ManejadorImagenes manejadorImagenes;
        private readonly EmailService _emailService;
        public static int rol = 0;

        public LoginController()
        {
            _manejadorUsuario = new ManejadorUsuario();
            manejadorImagenes = new ManejadorImagenes();
            _emailService = new EmailService();
        }

        public IActionResult Login()
        {
            Response.Headers["Cache-Control"] = "no-cache, no-store, must-revalidate";
            Response.Headers["Pragma"] = "no-cache";
            Response.Headers["Expires"] = "0";

            // Obtener banners de sesión con URLs de Cloudinary
            var bannersSesion = manejadorImagenes.ListarBannersSesion();
            var bannerSesion = bannersSesion.Select(b => new {
                Id = b.Id,
                Nombre = b.Nombre ?? "",
                Url = b.CloudinaryUrl,
                Formato = b.Formato
            }).ToList();

            ViewBag.BannerSesion = bannerSesion;
            return View();
        }

        [HttpPost]
        public IActionResult Login(Usuario usuario)
        {
            ManejadorUsuario manejador = new ManejadorUsuario();
            DataTable data = manejador.Login(usuario.Correo, usuario.Contrasenia);

            if (data.Rows.Count == 0)
            {
                TempData["Error"] = "Credenciales incorrectas. Por favor, verifica tu usuario y contraseña.";
                return View(usuario);
            }

            try
            {
                int idRol = Convert.ToInt32(data.Rows[0]["FK_ID_ROL"]);
                int idPersona = Convert.ToInt32(data.Rows[0]["FK_ID_PERSONA"]);
                int idUsuario = Convert.ToInt32(data.Rows[0]["PK_ID_USUARIO"]);
                int idTipoMembresia = 0;
                if (data.Rows[0]["FK_ID_TIPOMEMBRESIA"] == "")
                {
                    idTipoMembresia = Convert.ToInt32(data.Rows[0]["FK_ID_TIPOMEMBRESIA"]);

                }

                HttpContext.Session.SetInt32("PersonaId", idPersona);
                HttpContext.Session.SetInt32("idUsuario", idUsuario);
                HttpContext.Session.SetString("membresia", ((data.Rows[0]["FK_ID_TIPOMEMBRESIA"] == "") ? "sin membresia" : idTipoMembresia.ToString()));

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
                        HttpContext.Session.SetString("LastLoginError", usuario.Correo);
                        return View(usuario);
                    case 0:
                        TempData["Error"] = "Tu cuenta ha sido bloqueada por demasiados intentos fallidos. Inténtalo en una hora.";
                        return View(usuario);
                    default:
                        HttpContext.Session.Remove("LastLoginError");

                        GuardarPermisosRol(idRol);
                        return Redirect("~/Home/Principal");
                }
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Error al procesar la solicitud. Por favor registrate e intenta de nuevo.";
                Console.WriteLine($"Error en Login: {ex.Message}");
                return View(usuario);
            }
        }

        public IActionResult Logout()
        {
            HttpContext.Session.Clear();

            Response.Cookies.Delete(".AspNetCore.Session");
            Response.Cookies.Delete(".AspNetCore.Cookies");

            HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);

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

        public IActionResult LoginWithGoogle()
        {
            HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);

            var properties = new AuthenticationProperties
            {
                RedirectUri = Url.Action("GoogleResponse"),
                IsPersistent = false,
                AllowRefresh = true
            };

            properties.Items["prompt"] = "select_account";
            return Challenge(properties, GoogleDefaults.AuthenticationScheme);
        }
        private bool EsCorreoValido(string correo)
        {
            return Regex.IsMatch(correo, @"^[^@\s]+@[^@\s]+\.[^@\s]+$");
        }

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

                if (rol == 0)
                {
                    int userId = manejador.RegistrarUsuarioGoogle(email, name);
                    if (userId == 0)
                    {
                        TempData["Error"] = "Hubo un problema al registrar tu cuenta con Google.";
                        return RedirectToAction("Login");
                    }

                    data = manejador.LoginGoogle(email);
                    rol = data.Rows.Count > 0 ? Convert.ToInt32(data.Rows[0]["FK_ID_ROL"]) : 0;
                }

                if (data.Rows.Count > 0)
                {
                    int idUsuario = Convert.ToInt32(data.Rows[0]["PK_ID_USUARIO"]);
                    int idPersona = Convert.ToInt32(data.Rows[0]["FK_ID_PERSONA"]);
                    string membresia = data.Rows[0]["FK_ID_TIPOMEMBRESIA"]?.ToString() ?? "sin membresia";

                    HttpContext.Session.SetInt32("idUsuario", idUsuario);
                    HttpContext.Session.SetInt32("PersonaId", idPersona);
                    HttpContext.Session.SetString("membresia", string.IsNullOrWhiteSpace(membresia) ? "sin membresia" : membresia);
                }

                HttpContext.Session.SetString("userEmail", email);
                HttpContext.Session.SetString("userName", name);
                HttpContext.Session.SetInt32("userRol", rol);

                GuardarPermisosRol(rol);

                await HttpContext.SignInAsync(
                    CookieAuthenticationDefaults.AuthenticationScheme,
                    result.Principal,
                    new AuthenticationProperties { IsPersistent = false });

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

        [HttpPost]
        public async Task<IActionResult> RecuperarContrasenia(string Correo)
        {
            if (string.IsNullOrEmpty(Correo))
            {
                TempData["Error"] = "Por favor, ingresa un correo válido.";
                return View();
            }

            DataTable data = _manejadorUsuario.ObtenerUsuarioPorCorreo(Correo);

            if (data == null || data.Rows.Count == 0)
            {
                TempData["Error"] = "El correo no está registrado.";
                return View();
            }

            int userId = Convert.ToInt32(data.Rows[0]["PK_ID_USUARIO"]);

            _manejadorUsuario.GenerarTokenRecuperacion(userId);
            string token = _manejadorUsuario.ObtenerTokenRecuperacion(userId);

            if (string.IsNullOrEmpty(token))
            {
                TempData["Error"] = "Error al obtener el token de recuperación.";
                return RedirectToAction("RecuperarContrasenia");
            }

            TempData["CorreoIngresado"] = Correo;
            TempData["MostrarCodigo"] = true;

            var (success, message) = await _emailService.EnviarCodigoRecuperacion(Correo, "", token);

            if (success)
            {
                TempData["Success"] = "Se ha enviado un código a tu correo. Revisa tu bandeja de entrada.";
            }
            else
            {
                TempData["Error"] = "Hubo un problema al enviar el correo. Por favor intenta nuevamente.";
            }

            return RedirectToAction("RecuperarContrasenia");
        }

        [HttpPost]
        public IActionResult ValidarCodigoRecuperacion(string Codigo)
        {
            if (string.IsNullOrEmpty(Codigo))
            {
                TempData["Error"] = "Por favor, ingresa un código válido.";
                TempData["MostrarCodigo"] = true;
                return RedirectToAction("RecuperarContrasenia");
            }

            DataTable data = _manejadorUsuario.ValidarTokenRecuperacion(Codigo);

            if (data == null || data.Rows.Count == 0)
            {
                TempData["Error"] = "El código ingresado es incorrecto o ha expirado.";
                TempData["MostrarCodigo"] = true;
                return RedirectToAction("RecuperarContrasenia");
            }

            return RedirectToAction("IngresarNuevaContrasenia", new { token = Codigo });
        }

        public IActionResult IngresarNuevaContrasenia(string token)
        {
            if (string.IsNullOrEmpty(token) || !_manejadorUsuario.ValidarToken(token, out int userId))
            {
                TempData["Error"] = "El código de recuperación es inválido o ha expirado.";
                return RedirectToAction("RecuperarContrasenia");
            }

            ViewBag.UserId = userId;
            ViewBag.Token = token;
            return View();
        }

        [HttpPost]
        public IActionResult IngresarNuevaContrasenia(int userId, string NuevaContrasenia, string ConfirmarContrasenia)
        {
            if (string.IsNullOrEmpty(NuevaContrasenia) || string.IsNullOrEmpty(ConfirmarContrasenia))
            {
                TempData["Error"] = "Todos los campos son obligatorios.";
                return View();
            }

            if (NuevaContrasenia != ConfirmarContrasenia)
            {
                TempData["Error"] = "Las contraseñas no coinciden.";
                return View();
            }

            bool resultado = _manejadorUsuario.CambiarContrasenia(userId, NuevaContrasenia);

            if (!resultado)
            {
                TempData["Error"] = "Hubo un problema al cambiar la contraseña. Inténtalo de nuevo.";
                return View();
            }

            ViewData["Success"] = "¡Tu contraseña ha sido restablecida exitosamente!";
            TempData.Keep("Success");
            return RedirectToAction("Login");
        }

    }
}
