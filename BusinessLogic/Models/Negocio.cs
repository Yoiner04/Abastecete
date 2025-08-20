using Microsoft.AspNetCore.Http;
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
        public int TipoMembresia { get; set; }
        public string Nombre { get; set; }
        public string Localizacion { get; set; }
        public string Direccion { get; set; }
        public long Telefono { get; set; }
        public float Puntuacion { get; set; } = 5;
        public string? LogotipoId { get; set; }
        public IFormFile? logotipoArchivo { get; set; }
        public ImagenModel imagen { get; set; }
        public string BannerId { get; set; }
        public ImagenModel BannerImagen { get; set; }

        public string Descripcion { get; set; }
    }
}
