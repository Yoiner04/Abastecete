using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BusinessLogic.Models
{
    public class OfertaFlash
    {
        public int Id { get; set; }
        public string Titulo { get; set; }
        public string Descripcion { get; set; }
        public int Estado { get; set; }
        public DateTime FechaOferta { get; set; }
        public DateTime TiempoOferta { get; set; }
        public int IdLocal { get; set; }
        public string NombreLocal { get; set; }
        public string FotoLocal { get; set; }
    }
}

