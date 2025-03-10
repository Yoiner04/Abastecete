using MercadoPago.Client.Preference;
using MercadoPago.Config;
using MercadoPago.Resource.Preference;
using Microsoft.AspNetCore.Mvc;

namespace Abastecete.Controllers
{
    [Route("api/pagos")]
    [ApiController]
    public class PagosController : ControllerBase
    {
        private readonly IConfiguration _config;

        public PagosController(IConfiguration config)
        {
            _config = config;
            MercadoPagoConfig.AccessToken = _config["MercadoPago:AccessToken"];
        }

        [HttpPost("checkout-pro")]
        public async Task<IActionResult> CrearPreferencia()
        {
            var request = new PreferenceRequest
            {
                Items = new List<PreferenceItemRequest>
            {
                new PreferenceItemRequest
                {
                    Title = "",
                    Quantity = 1,
                    CurrencyId = "COP",
                    UnitPrice = 0
                }
            },
                BackUrls = new PreferenceBackUrlsRequest
                {
                    Success = "",
                    Failure = "",
                    Pending = ""
                },
                AutoReturn = "approved"
            };

            var client = new PreferenceClient();
            Preference preference = await client.CreateAsync(request);

            return Ok(new { url = preference.InitPoint });
        }
    }
}
