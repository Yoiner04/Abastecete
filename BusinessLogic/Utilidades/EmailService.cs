using System;
using System.Net;
using System.Net.Mail;
using System.Threading.Tasks;

namespace BusinessLogic.Utilidades
{
    public class EmailService
    {
        private readonly string _smtpHost = "smtp.gmail.com";
        private readonly int _smtpPort = 587;
        private readonly string _smtpUser = "abastecetecol@gmail.com";
        private readonly string _smtpPass = "mvijnlfiegwohmsm";
        private readonly string _emailTo = "abastecetecol@gmail.com";
        private readonly string _emailFrom = "abastecetecol@gmail.com";

        public async Task<bool> EnviarCorreoContacto(string email, string phone, string message)
        {
            try
            {
                using (var client = new SmtpClient(_smtpHost, _smtpPort))
                {
                    client.Credentials = new NetworkCredential(_smtpUser, _smtpPass);
                    client.EnableSsl = true;

                    var mailMessage = new MailMessage
                    {
                        From = new MailAddress(_emailFrom),
                        Subject = "Nuevo mensaje de contacto",
                        Body = $"Correo: {email}\nTeléfono (+57): {phone}\nMensaje:\n{message}",
                        IsBodyHtml = false
                    };

                    mailMessage.To.Add(_emailTo);

                    await client.SendMailAsync(mailMessage);
                    return true;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error enviando correo: {ex.Message}");
                return false;
            }
        }
    }
}