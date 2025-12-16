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
                var (success, message) = await _emailService.EnviarCorreoContacto(model.Email, model.Phone, model.Message);
                if (success)
                {
                    return Ok(new { success = true, message = "Mensaje enviado correctamente." });
                }
                return BadRequest(new { success = false, message });
            }
            return BadRequest(new { success = false, message = "Datos inválidos." });
        }

        [HttpPost("opinion")]
        public async Task<IActionResult> SendFooterOpinion([FromForm] OpinionModel model)
        {
            if (ModelState.IsValid)
            {
                string asunto = "Opinión desde el formulario de Abastecete";
                string cuerpo = $"Nombre: {model.Nombre}\nCorreo: {model.Correo}\nTeléfono: {model.Telefono}\n\nOpinión:\n{model.Mensaje}";

                var (success, message) = await _emailService.EnviarCorreoOpinion(asunto, cuerpo);

                if (success)
                    return Ok(new { success = true, message = "Opinión enviada correctamente." });

                return BadRequest(new { success = false, message });
            }
            return BadRequest(new { success = false, message = "Datos inválidos." });
        }
    }

    public class ContactFormModel
    {
        public string Email
        { get; set; }
        public string Phone { get; set; }
        public string Message { get; set; }
    }

    public class OpinionModel
    {
        public string Nombre { get; set; }
        public string Correo { get; set; }
        public string Telefono { get; set; }
        public string Mensaje { get; set; }
    }
}
