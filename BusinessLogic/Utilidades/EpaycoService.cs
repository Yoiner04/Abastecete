using BusinessLogic.Interfaces;
using RestSharp;
using Microsoft.Extensions.Configuration;
using System;
using System.Threading.Tasks;
using BusinessLogic.Models;

namespace BusinessLogic.Utilidades
{
    public class EpaycoService : IEpaycoService
    {
        private readonly string _privateKey;
        private readonly string _publicKey;

        public EpaycoService(IConfiguration configuration)
        {
            _privateKey = configuration["Epayco:PrivateKey"];
            _publicKey = configuration["Epayco:PublicKey"];
        }

        public async Task<string> ProcessPayment(EpaycoPaymentRequest request)
        {
            var client = new RestClient("https://api.secure.epayco.co");
            var restRequest = new RestRequest("/payment/process", Method.Post);
            restRequest.AddHeader("Content-Type", "application/json");

            var body = new
            {
                key = _publicKey,
                token_card = request.TokenCard,
                customer_id = request.CustomerId,
                doc_type = request.DocType,
                doc_number = request.DocNumber,
                name = request.Name,
                last_name = request.LastName,
                email = request.Email,
                bill = request.Bill,
                description = request.Description,
                value = request.Value,
                tax = request.Tax,
                tax_base = request.TaxBase,
                currency = request.Currency,
                dues = request.Dues
            };

            restRequest.AddJsonBody(body);
            var response = await client.ExecuteAsync(restRequest);

            if (!response.IsSuccessful)
                throw new Exception($"Error en pago: {response.Content}");

            return response.Content;
        }
    }
}
