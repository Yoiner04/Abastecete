using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BusinessLogic.Models
{
    public class Producto
    {
        public int Id { get; set; }
        public int IdSubCategoria { get; set; }
        public string Nombre { get; set; }
        public decimal Precio { get; set; }
        public string ImagenUrl { get; set; }


    }
}
