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
using Abastecete.Models;
using System.Net.Mail;
using System.Net;

namespace ConnectionProject.Controllers
{
    public class LoginController : Controller
    {
        private readonly ManejadorUsuario _manejadorUsuario;
        public static int rol = 0;

        public LoginController()
        {
            _manejadorUsuario = new ManejadorUsuario();
        }

        public IActionResult Login()
        {
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
                int idTipoMembresia = Convert.ToInt32(data.Rows[0]["FK_ID_TIPOMEMBRESIA"]); // ✅ Ahora sí existe la columna

                HttpContext.Session.SetInt32("PersonaId", idPersona);
                HttpContext.Session.SetInt32("idUsuario", idUsuario);
                HttpContext.Session.SetString("membresia", idTipoMembresia.ToString());

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
                    if (data.Rows.Count > 0)
                    {
                        rol = Convert.ToInt32(data.Rows[0]["FK_ID_ROL"]);
                    }
                }

                HttpContext.Session.SetString("userEmail", email);
                HttpContext.Session.SetString("userName", name);
                HttpContext.Session.SetInt32("userRol", rol);

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

        [HttpPost]
        public IActionResult RecuperarContrasenia(string Correo)
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

            EnviarCorreoRecuperacion(Correo, token);

            TempData["Success"] = "Se ha enviado un código a tu correo.";
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



        private void EnviarCorreoRecuperacion(string correo, string token)
        {
            try
            {
                string asunto = "Código de recuperación de contraseña";
                string cuerpo = $"Tu código de recuperación es: {token}\n\n" +
                                $"Este código expirará en 5 minutos.\n\n" +
                                $"Ingresa este código en la página de recuperación de contraseña para continuar.";

                MailMessage mail = new MailMessage
                {
                    From = new MailAddress("abastecetecol@gmail.com"),
                    Subject = asunto,
                    Body = cuerpo,
                    IsBodyHtml = false
                };
                mail.To.Add(correo);

                string dominio = correo.Split('@')[1].ToLower();
                SmtpClient smtp = new SmtpClient();

                switch (dominio)
                {
                    case "gmail.com":
                        smtp.Host = "smtp.gmail.com";
                        break;
                    case "outlook.com":
                    case "hotmail.com":
                    case "live.com":
                        smtp.Host = "smtp.office365.com";
                        break;
                    case "yahoo.com":
                        smtp.Host = "smtp.mail.yahoo.com";
                        break;
                    case "zoho.com":
                        smtp.Host = "smtp.zoho.com";
                        break;
                    case "icloud.com":
                        smtp.Host = "smtp.mail.me.com";
                        break;
                    default:
                        smtp.Host = "smtp.tudominio.com";
                        break;
                }

                smtp.Port = 587;
                smtp.EnableSsl = true;
                smtp.Credentials = new NetworkCredential("abastecetecol@gmail.com", "mvijnlfiegwohmsm");

                smtp.Send(mail);
                Console.WriteLine($"✅ Correo enviado a {correo} con éxito.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"⚠️ Error al enviar el correo a {correo}: {ex.Message}");
            }
        }

    }
}