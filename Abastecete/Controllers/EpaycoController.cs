using BusinessLogic.Models;
using BusinessLogic.Utilidades;
using Microsoft.AspNetCore.Mvc;
using System.Threading.Tasks;

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
