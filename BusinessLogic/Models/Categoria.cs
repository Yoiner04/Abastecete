using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BusinessLogic.Models
{
    public class Categoria
    {
        public int Id { get; set; }
        public string Nombre { get; set; }
        public int Estado { get; set; }

        // Para MongoDB
        public string ImagenId { get; set; }
        public ImagenModel Imagen { get; set; }

        public string BannerId { get; set; }
        public ImagenModel BannerImagen { get; set; }
    }

}
