using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BusinessLogic.Models
{
    public class DetalleFacturacionModel
    {
        public int UsuarioId { get; set; }
        public int TipoMembresiaId { get; set; }
        public decimal Monto { get; set; }
        public string Nombre { get; set; } = "";
        public string Apellidos { get; set; } = "";
        public string? Empresa { get; set; }
        public string Direccion { get; set; } = "";
        public string Departamento { get; set; } = "";
        public string Municipio { get; set; } = "";
        public string Telefono { get; set; } = "";
        public string Correo { get; set; } = "";
    }
}
