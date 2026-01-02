using BusinessLogic.Models;
using BusinessLogic.Utilidades;
using Microsoft.AspNetCore.Mvc;
using System.Threading.Tasks;

namespace Abastecete.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class EpaycoController : ControllerBase
    {
        private readonly EpaycoService _epaycoService;

        public EpaycoController(EpaycoService epaycoService)
        {
            _epaycoService = epaycoService;
        }

        [HttpPost("process-payment")]
        public async Task<IActionResult> ProcessPayment([FromBody] EpaycoPaymentRequest request)
        {
            // Validar que el usuario esté autenticado
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            if (usuarioId == null)
            {
                return Unauthorized(new { Message = "Sesión no válida" });
            }

            // Validar request
            if (request == null)
            {
                return BadRequest(new { Message = "Datos de pago inválidos" });
            }

            try
            {
                var response = await _epaycoService.ProcessPayment(request);
                return Ok(new { Message = "Pago exitoso", Response = response });
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = "Error en el pago", Error = ex.Message });
            }
        }
    }
}
