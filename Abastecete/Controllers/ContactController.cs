using BusinessLogic.Utilidades;
using Microsoft.AspNetCore.Mvc;
using System.Threading.Tasks;

namespace Abastecete.Controllers
{
    [Route("api/contact")]
    [ApiController]
    public class ContactController : ControllerBase
    {
        private readonly EmailService _emailService;

        public ContactController()
        {
            _emailService = new EmailService();
        }

        [HttpPost("send")]
        public async Task<IActionResult> SendEmail([FromForm] ContactFormModel model)
        {
            if (ModelState.IsValid)
            {
                bool enviado = await _emailService.EnviarCorreoContacto(model.Email, model.Phone, model.Message);
                if (enviado)
                {
                    return Ok(new { success = true, message = "Mensaje enviado correctamente." });
                }
                return BadRequest(new { success = false, message = "Error al enviar el mensaje." });
            }
            return BadRequest(new { success = false, message = "Datos inválidos." });
        }
    }

    public class ContactFormModel
    {
        public string Email { get; set; }
        public string Phone { get; set; }
        public string Message { get; set; }
    }
}
