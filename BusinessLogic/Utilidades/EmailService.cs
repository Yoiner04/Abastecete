using System;
using System.Net;
using System.Net.Mail;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;

namespace BusinessLogic.Utilidades
{
    /// <summary>
    /// Servicio de envío de correos electrónicos con plantillas HTML profesionales
    /// </summary>
    public class EmailService
    {
        private readonly string _smtpHost;
        private readonly int _smtpPort;
        private readonly string _smtpUser;
        private readonly string _smtpPass;
        private readonly string _emailFrom;
        private readonly string _emailFromName;
        private readonly string _emailAdmin;

        public EmailService()
        {
            // Cargar configuración desde appsettings.json
            var configuration = new ConfigurationBuilder()
                .SetBasePath(AppDomain.CurrentDomain.BaseDirectory)
                .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
                .Build();

            var emailConfig = configuration.GetSection("EmailSettings");
            _smtpHost = emailConfig["SmtpHost"] ?? "smtp.gmail.com";
            _smtpPort = int.Parse(emailConfig["SmtpPort"] ?? "587");
            _smtpUser = emailConfig["SmtpUser"];
            _smtpPass = emailConfig["SmtpPass"];
            _emailFrom = emailConfig["EmailFrom"];
            _emailFromName = emailConfig["EmailFromName"] ?? "Abastecete";
            _emailAdmin = emailConfig["EmailAdmin"];
        }

        public EmailService(IConfiguration configuration)
        {
            var emailConfig = configuration.GetSection("EmailSettings");
            _smtpHost = emailConfig["SmtpHost"] ?? "smtp.gmail.com";
            _smtpPort = int.Parse(emailConfig["SmtpPort"] ?? "587");
            _smtpUser = emailConfig["SmtpUser"] ?? "abastecetecol@gmail.com";
            _smtpPass = emailConfig["SmtpPass"] ?? "";
            _emailFrom = emailConfig["EmailFrom"] ?? "abastecetecol@gmail.com";
            _emailFromName = emailConfig["EmailFromName"] ?? "Abastecete";
            _emailAdmin = emailConfig["EmailAdmin"] ?? "abastecetecol@gmail.com";
        }

        /// <summary>
        /// Envía un correo con el código de recuperación de contraseña
        /// </summary>
        public async Task<(bool Success, string Message)> EnviarCodigoRecuperacion(string destinatario, string nombreUsuario, string codigo)
        {
            try
            {
                string htmlBody = EmailTemplates.RecuperacionContrasenia(nombreUsuario, codigo);

                return await EnviarCorreoHtml(
                    destinatario,
                    "Código de recuperación de contraseña - Abastecete",
                    htmlBody
                );
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al enviar código de recuperación: {ex.Message}");
                return (false, "Error al enviar el correo de recuperación.");
            }
        }

        /// <summary>
        /// Envía un correo de bienvenida a nuevos usuarios
        /// </summary>
        public async Task<(bool Success, string Message)> EnviarBienvenida(string destinatario, string nombreUsuario)
        {
            try
            {
                string htmlBody = EmailTemplates.BienvenidaUsuario(nombreUsuario, destinatario);

                return await EnviarCorreoHtml(
                    destinatario,
                    "¡Bienvenido a Abastecete!",
                    htmlBody
                );
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al enviar correo de bienvenida: {ex.Message}");
                return (false, "Error al enviar el correo de bienvenida.");
            }
        }

        /// <summary>
        /// Envía confirmación de cambio de contraseña
        /// </summary>
        public async Task<(bool Success, string Message)> EnviarConfirmacionCambioContrasenia(string destinatario, string nombreUsuario)
        {
            try
            {
                string htmlBody = EmailTemplates.ContraseniaCambiada(nombreUsuario);

                return await EnviarCorreoHtml(
                    destinatario,
                    "Tu contraseña ha sido actualizada - Abastecete",
                    htmlBody
                );
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al enviar confirmación de cambio: {ex.Message}");
                return (false, "Error al enviar el correo de confirmación.");
            }
        }

        /// <summary>
        /// Envía notificación de cuenta bloqueada
        /// </summary>
        public async Task<(bool Success, string Message)> EnviarNotificacionBloqueo(string destinatario, string nombreUsuario)
        {
            try
            {
                string htmlBody = EmailTemplates.CuentaBloqueada(nombreUsuario);

                return await EnviarCorreoHtml(
                    destinatario,
                    "Aviso de seguridad: cuenta bloqueada temporalmente - Abastecete",
                    htmlBody
                );
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al enviar notificación de bloqueo: {ex.Message}");
                return (false, "Error al enviar la notificación.");
            }
        }

        /// <summary>
        /// Envía un mensaje de contacto al administrador
        /// </summary>
        public async Task<(bool Success, string Message)> EnviarCorreoContacto(string emailRemitente, string telefono, string mensaje)
        {
            try
            {
                string htmlBody = EmailTemplates.NotificacionContacto(emailRemitente, telefono, mensaje);

                return await EnviarCorreoHtml(
                    _emailAdmin,
                    $"Nuevo mensaje de contacto de {emailRemitente}",
                    htmlBody,
                    emailRemitente // Reply-To
                );
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al enviar mensaje de contacto: {ex.Message}");
                return (false, "Error al enviar el mensaje.");
            }
        }

        /// <summary>
        /// Envía un correo de opinión/aviso al administrador
        /// </summary>
        public async Task<(bool Success, string Message)> EnviarCorreoOpinion(string asunto, string cuerpo)
        {
            try
            {
                return await EnviarCorreoHtml(_emailAdmin, asunto, FormatearTextoPlanoAHtml(cuerpo));
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al enviar opinión: {ex.Message}");
                return (false, "Error al enviar el correo.");
            }
        }

        /// <summary>
        /// Envía un correo de aviso al administrador
        /// </summary>
        public async Task<(bool Success, string Message)> EnviarCorreoAviso(string asunto, string mensaje)
        {
            try
            {
                return await EnviarCorreoHtml(_emailAdmin, asunto, FormatearTextoPlanoAHtml(mensaje));
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al enviar aviso: {ex.Message}");
                return (false, "Error al enviar el correo.");
            }
        }

        /// <summary>
        /// Método interno para enviar correos HTML
        /// </summary>
        private async Task<(bool Success, string Message)> EnviarCorreoHtml(
            string destinatario,
            string asunto,
            string htmlBody,
            string replyTo = null)
        {
            try
            {
                using (var client = new SmtpClient(_smtpHost, _smtpPort))
                {
                    client.Credentials = new NetworkCredential(_smtpUser, _smtpPass);
                    client.EnableSsl = true;
                    client.Timeout = 30000; // 30 segundos

                    var mailMessage = new MailMessage
                    {
                        From = new MailAddress(_emailFrom, _emailFromName),
                        Subject = asunto,
                        Body = htmlBody,
                        IsBodyHtml = true,
                        Priority = MailPriority.Normal
                    };

                    mailMessage.To.Add(destinatario);

                    if (!string.IsNullOrEmpty(replyTo))
                    {
                        mailMessage.ReplyToList.Add(new MailAddress(replyTo));
                    }

                    // Headers adicionales para mejor entregabilidad
                    mailMessage.Headers.Add("X-Mailer", "Abastecete-Mailer");
                    mailMessage.Headers.Add("X-Priority", "3");

                    await client.SendMailAsync(mailMessage);

                    Console.WriteLine($"Correo enviado exitosamente a {destinatario}");
                    return (true, "Correo enviado exitosamente.");
                }
            }
            catch (SmtpException smtpEx)
            {
                Console.WriteLine($"Error SMTP al enviar correo a {destinatario}: {smtpEx.Message}");
                return (false, $"Error de servidor de correo: {smtpEx.StatusCode}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al enviar correo a {destinatario}: {ex.Message}");
                return (false, "Error al enviar el correo. Por favor intenta más tarde.");
            }
        }

        /// <summary>
        /// Convierte texto plano a HTML básico
        /// </summary>
        private string FormatearTextoPlanoAHtml(string texto)
        {
            if (string.IsNullOrEmpty(texto))
                return string.Empty;

            string htmlTexto = System.Web.HttpUtility.HtmlEncode(texto);
            htmlTexto = htmlTexto.Replace("\n", "<br>");

            return $@"
<!DOCTYPE html>
<html>
<head>
    <meta charset='UTF-8'>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; padding: 20px; }}
    </style>
</head>
<body>
    <div style='max-width: 600px; margin: 0 auto;'>
        <h2 style='color: #2563eb;'>Abastecete</h2>
        <div>{htmlTexto}</div>
        <hr style='margin: 20px 0; border: none; border-top: 1px solid #eee;'>
        <p style='font-size: 12px; color: #666;'>Este correo fue enviado desde Abastecete.</p>
    </div>
</body>
</html>";
        }
    }
}
