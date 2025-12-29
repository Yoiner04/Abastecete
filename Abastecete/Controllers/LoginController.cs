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
        private readonly ManejadorLogs _manejadorLogs;
        public static int rol = 0;

        public LoginController()
        {
            _manejadorUsuario = new ManejadorUsuario();
            manejadorImagenes = new ManejadorImagenes();
            _emailService = new EmailService();
            _manejadorLogs = new ManejadorLogs();
        }

        /// <summary>
        /// Registra log de autenticación de forma asíncrona (fire-and-forget) para no bloquear el login
        /// </summary>
        private void RegistrarLogAutenticacion(int? usuarioId, string nombreUsuario, string tipoAccion, string resultado, string mensajeError = null)
        {
            // Capturar datos del contexto antes del Task (HttpContext no es thread-safe)
            var ipCliente = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
            var forwardedFor = HttpContext.Request.Headers["X-Forwarded-For"].FirstOrDefault();
            if (!string.IsNullOrEmpty(forwardedFor))
                ipCliente = forwardedFor.Split(',').First().Trim();
            var userAgent = HttpContext.Request.Headers["User-Agent"].FirstOrDefault() ?? "";

            // Fire-and-forget: no esperamos el resultado
            Task.Run(() =>
            {
                try
                {
                    var manejadorLogs = new ManejadorLogs();
                    manejadorLogs.RegistrarLog(
                        usuarioId,
                        nombreUsuario ?? "Anonimo",
                        ModulosAuditoria.AUTENTICACION,
                        tipoAccion,
                        usuarioId,
                        tipoAccion == TiposAccionAuditoria.LOGIN ? "Inicio de sesion" : "Cierre de sesion",
                        null,
                        null,
                        ipCliente,
                        userAgent,
                        resultado,
                        mensajeError,
                        "Login",
                        tipoAccion == TiposAccionAuditoria.LOGIN ? "Login" : "Logout"
                    );
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[AUTH LOG ERROR] {ex.Message}");
                }
            });
        }

        public IActionResult Login()
        {
            Response.Headers["Cache-Control"] = "no-cache, no-store, must-revalidate";
            Response.Headers["Pragma"] = "no-cache";
            Response.Headers["Expires"] = "0";

            // Los banners se cargan via AJAX para no bloquear el renderizado de la página
            ViewBag.BannerSesion = new List<object>();
            return View();
        }

        /// <summary>
        /// Endpoint para cargar banners de sesión de forma asíncrona (no bloquea el login)
        /// </summary>
        [HttpGet]
        public IActionResult ObtenerBannersSesion()
        {
            try
            {
                var bannersSesion = manejadorImagenes.ListarBannersSesion();
                var bannerSesion = bannersSesion.Select(b => new {
                    Id = b.Id,
                    Nombre = b.Nombre ?? "",
                    Url = b.CloudinaryUrl,
                    Formato = b.Formato
                }).ToList();

                return Json(bannerSesion);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al obtener banners: {ex.Message}");
                return Json(new List<object>());
            }
        }

        [HttpPost]
        public IActionResult Login(Usuario usuario)
        {
            var swTotal = System.Diagnostics.Stopwatch.StartNew();
            var sw = System.Diagnostics.Stopwatch.StartNew();

            // Reutilizar el manejador existente en lugar de crear uno nuevo
            DataTable data = _manejadorUsuario.Login(usuario.Correo, usuario.Contrasenia);

            Console.WriteLine($"[LOGIN TIMING] Login DB query: {sw.ElapsedMilliseconds}ms");
            sw.Restart();

            if (data.Rows.Count == 0)
            {
                RegistrarLogAutenticacion(null, usuario.Correo, TiposAccionAuditoria.LOGIN, "ERROR", "Credenciales incorrectas");
                TempData["Error"] = "Credenciales incorrectas. Por favor, verifica tu usuario y contraseña.";
                return View(usuario);
            }

            try
            {
                int codigoEstado = Convert.ToInt32(data.Rows[0]["CODIGO_ESTADO"]);

                // Primero verificar errores de login antes de acceder a otros campos
                switch (codigoEstado)
                {
                    case 97:
                        RegistrarLogAutenticacion(null, usuario.Correo, TiposAccionAuditoria.LOGIN, "ERROR", "Cuenta inhabilitada");
                        TempData["Error"] = "Tu cuenta ha sido inhabilitada.";
                        return View(usuario);
                    case 98:
                        RegistrarLogAutenticacion(null, usuario.Correo, TiposAccionAuditoria.LOGIN, "ERROR", "Correo no valido");
                        TempData["Error"] = "Correo electrónico no válido.";
                        return View(usuario);
                    case 99:
                        RegistrarLogAutenticacion(null, usuario.Correo, TiposAccionAuditoria.LOGIN, "ERROR", "Contrasena incorrecta");
                        TempData["Error"] = "Contraseña incorrecta. Si fallas 5 veces, tu cuenta será bloqueada.";
                        HttpContext.Session.SetString("LastLoginError", usuario.Correo);
                        return View(usuario);
                    case 0:
                        RegistrarLogAutenticacion(null, usuario.Correo, TiposAccionAuditoria.LOGIN, "ERROR", "Cuenta bloqueada por intentos fallidos");
                        TempData["Error"] = "Tu cuenta ha sido bloqueada por demasiados intentos fallidos. Inténtalo en una hora.";
                        return View(usuario);
                }

                // Solo si el login fue exitoso, obtener los demás datos
                int idUsuario = Convert.ToInt32(data.Rows[0]["PK_ID_USUARIO"]);

                // Obtener tipo de membresía de forma segura
                int idTipoMembresia = 0;
                var membresiaValue = data.Rows[0]["FK_ID_TIPOMEMBRESIA"];
                if (membresiaValue != DBNull.Value && membresiaValue != null)
                {
                    idTipoMembresia = Convert.ToInt32(membresiaValue);
                }

                HttpContext.Session.SetInt32("idUsuario", idUsuario);
                HttpContext.Session.SetString("membresia", idTipoMembresia > 0 ? idTipoMembresia.ToString() : "sin membresia");

                // Guardar ID del local si el usuario tiene uno
                var idLocalValue = data.Rows[0]["ID_LOCAL"];
                if (idLocalValue != DBNull.Value && idLocalValue != null)
                {
                    int idLocal = Convert.ToInt32(idLocalValue);
                    if (idLocal > 0)
                    {
                        HttpContext.Session.SetInt32("idLocal", idLocal);
                    }
                }

                Console.WriteLine($"[LOGIN TIMING] Session setup: {sw.ElapsedMilliseconds}ms");
                sw.Restart();

                if (HttpContext.Session.GetString("LastLoginError") == usuario.Correo)
                {
                    TempData["Error"] = "Contraseña incorrecta. Si fallas 5 veces, tu cuenta será bloqueada.";
                    return View(usuario);
                }

                // Login exitoso
                HttpContext.Session.Remove("LastLoginError");

                // Cargar permisos (unificado - evita llamadas duplicadas a DB)
                GuardarTodosLosPermisos(idUsuario);

                // Registrar login exitoso
                RegistrarLogAutenticacion(idUsuario, usuario.Correo, TiposAccionAuditoria.LOGIN, "EXITO");

                Console.WriteLine($"[LOGIN TIMING] Permisos loaded: {sw.ElapsedMilliseconds}ms");
                Console.WriteLine($"[LOGIN TIMING] TOTAL: {swTotal.ElapsedMilliseconds}ms");
                return Redirect("~/Home/Principal");
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
            // Obtener datos del usuario antes de limpiar la sesion
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            var nombreUsuario = HttpContext.Session.GetString("nombreUsuario") ?? "Usuario";

            // Registrar logout antes de limpiar sesion
            RegistrarLogAutenticacion(usuarioId, nombreUsuario, TiposAccionAuditoria.LOGOUT, "EXITO");

            HttpContext.Session.Clear();

            Response.Cookies.Delete(".AspNetCore.Session");
            Response.Cookies.Delete(".AspNetCore.Cookies");

            HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);

            Response.Headers["Cache-Control"] = "no-cache, no-store, must-revalidate";
            Response.Headers["Pragma"] = "no-cache";
            Response.Headers["Expires"] = "0";

            return RedirectToAction("Login");
        }

        /// <summary>
        /// Carga todos los permisos del usuario en sesión
        /// </summary>
        private void GuardarTodosLosPermisos(int idUsuario)
        {
            var sw = System.Diagnostics.Stopwatch.StartNew();
            ManejadorPermisos manejadorP = new ManejadorPermisos();

            // Cargar permisos del nuevo sistema por membresía (UNA sola llamada a DB)
            var permisos = manejadorP.ObtenerDiccionarioPermisos(idUsuario);
            HttpContext.Session.SetString("permisosSistema", JsonConvert.SerializeObject(permisos));

            // También guardar en "permisos" para compatibilidad con código legacy
            HttpContext.Session.SetString("permisos", JsonConvert.SerializeObject(permisos));

            Console.WriteLine($"[PERMISOS TIMING] Permisos cargados: {sw.ElapsedMilliseconds}ms ({permisos.Count} permisos)");
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

                // Usar el manejador existente en lugar de crear uno nuevo
                DataTable data = _manejadorUsuario.LoginGoogle(email);

                int codigoEstado = data.Rows.Count > 0 ? Convert.ToInt32(data.Rows[0]["CODIGO_ESTADO"]) : 0;

                // Validar estados de error igual que en login normal
                switch (codigoEstado)
                {
                    case 97:
                        TempData["Error"] = "Tu cuenta ha sido inhabilitada.";
                        return RedirectToAction("Login");
                    case 0 when data.Rows.Count > 0:
                        TempData["Error"] = "Tu cuenta ha sido bloqueada.";
                        return RedirectToAction("Login");
                }

                // Usuario no existe, registrarlo
                if (codigoEstado == 0 && data.Rows.Count == 0)
                {
                    int userId = _manejadorUsuario.RegistrarUsuarioGoogle(email, name);
                    if (userId == 0)
                    {
                        TempData["Error"] = "Hubo un problema al registrar tu cuenta con Google.";
                        return RedirectToAction("Login");
                    }

                    data = _manejadorUsuario.LoginGoogle(email);
                    codigoEstado = data.Rows.Count > 0 ? Convert.ToInt32(data.Rows[0]["CODIGO_ESTADO"]) : 0;
                }

                if (data.Rows.Count > 0)
                {
                    int idUsuario = Convert.ToInt32(data.Rows[0]["PK_ID_USUARIO"]);

                    // Manejo seguro de FK_ID_TIPOMEMBRESIA
                    string membresia = "sin membresia";
                    var membresiaValue = data.Rows[0]["FK_ID_TIPOMEMBRESIA"];
                    if (membresiaValue != DBNull.Value && membresiaValue != null)
                    {
                        string membresiaStr = membresiaValue.ToString();
                        if (!string.IsNullOrWhiteSpace(membresiaStr))
                        {
                            membresia = membresiaStr;
                        }
                    }

                    HttpContext.Session.SetInt32("idUsuario", idUsuario);
                    HttpContext.Session.SetString("membresia", membresia);
                }

                HttpContext.Session.SetString("userEmail", email);
                HttpContext.Session.SetString("userName", name);

                // Cargar permisos (unificado)
                var idUsuarioGoogle = HttpContext.Session.GetInt32("idUsuario");
                if (idUsuarioGoogle.HasValue)
                {
                    GuardarTodosLosPermisos(idUsuarioGoogle.Value);
                }

                await HttpContext.SignInAsync(
                    CookieAuthenticationDefaults.AuthenticationScheme,
                    result.Principal,
                    new AuthenticationProperties { IsPersistent = false });

                return Redirect("~/Home/Principal");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error en GoogleResponse: {ex.Message}");
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
