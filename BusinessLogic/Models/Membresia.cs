using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BusinessLogic.Models
{
    public class Membresia
    {
        public int Id { get; set; }
        public string Nombre { get; set; }
        public string Descripcion { get; set; }
        public float Costo { get; set; }
        public int Estado { get; set; }
        public int Costo_trimestral { get; set; }
        public int Costo_semestral { get; set; }
        public int Costo_anual { get; set; }
    }
}
