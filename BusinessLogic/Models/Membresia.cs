using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
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

        public int Duracion { get; set; }
        public int Cantidad { get; set; }
        public float Costo_trimestral { get; set; }
        public float Costo_semestral { get; set; }
        public float Costo_anual { get; set; }
    }
}
