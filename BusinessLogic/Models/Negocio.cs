using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BusinessLogic.Models
{
    public class Negocio
    {
        public int Id { get; set; }
        public Persona Persona { get; set; }
        public int Estado { get; set; }
        public string Nombre { get; set; }
        public string Direccion { get; set; }
        public string Ubicacion { get; set; }
        public int Telefono { get; set; }
        public string Logotipo { get; set; }
    }
}
