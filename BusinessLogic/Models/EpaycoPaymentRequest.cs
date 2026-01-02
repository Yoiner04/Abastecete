using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BusinessLogic.Models
{
    public class EpaycoPaymentRequest
    {
        public string Key { get; set; } = ""; // Public Key
        public string TokenCard { get; set; } = "";
        public string CustomerId { get; set; } = "";
        public string DocType { get; set; } = "";
        public string DocNumber { get; set; } = "";
        public string Name { get; set; } = "";
        public string LastName { get; set; } = "";
        public string Email { get; set; } = "";
        public string Bill { get; set; } = "";
        public string Description { get; set; } = "";
        public string Value { get; set; } = "";
        public string Tax { get; set; } = "";
        public string TaxBase { get; set; } = "";
        public string Currency { get; set; } = "";
        public string Dues { get; set; } = "";
    }

}
