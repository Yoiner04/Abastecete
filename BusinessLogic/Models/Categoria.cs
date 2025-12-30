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
        public string Nombre { get; set; } = "";
        public int Estado { get; set; }

        // URL de imagen en Cloudinary
        public string? ImagenId { get; set; }
        public ImagenModel? Imagen { get; set; }
        public string? CloudinaryPublicIdImagen { get; set; }

        // URL de banner en Cloudinary
        public string? BannerId { get; set; }
        public ImagenModel? BannerImagen { get; set; }
        public string? CloudinaryPublicIdBanner { get; set; }
    }

}
