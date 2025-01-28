using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BusinessLogic.Models
{
    public class Persona
    {
        public int Id { get; set; }

        [Required]
        public string Nombre { get; set; }

        [Required]
        public string Apellido { get; set; }

        [Required]
        public int TipoDeDocumento { get; set; }

        [Required]
        public int Documento { get; set; }

        [Required]
        public string Telefono { get; set; }

        [Required]
        public string Estado { get; set; }
    }
}
