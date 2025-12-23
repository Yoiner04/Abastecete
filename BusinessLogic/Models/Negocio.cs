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
        public Suscripcion SuscripcionActiva { get; set; }
        public string Nombre { get; set; }
        public string Localizacion { get; set; }
        public string Direccion { get; set; }
        public long Telefono { get; set; }
        public float Puntuacion { get; set; } = 5;
        public string? LogotipoId { get; set; }
        public string? CloudinaryPublicIdLogotipo { get; set; }
        public IFormFile? logotipoArchivo { get; set; }
        public ImagenModel imagen { get; set; }
        public string BannerId { get; set; }
        public ImagenModel BannerImagen { get; set; }
        public string Descripcion { get; set; }

        // Contacto adicional
        public string? EmailContacto { get; set; }
        public string? Whatsapp { get; set; }
        public string? SitioWeb { get; set; }
        public string? Nit { get; set; }

        // Redes sociales
        public string? Instagram { get; set; }
        public string? Facebook { get; set; }
        public string? Tiktok { get; set; }
        public string? Youtube { get; set; }
        public string? Twitter { get; set; }

        // Horarios estructurados
        public string? HorarioLunes { get; set; }
        public string? HorarioMartes { get; set; }
        public string? HorarioMiercoles { get; set; }
        public string? HorarioJueves { get; set; }
        public string? HorarioViernes { get; set; }
        public string? HorarioSabado { get; set; }
        public string? HorarioDomingo { get; set; }

        // Coordenadas GPS
        public decimal? Latitud { get; set; }
        public decimal? Longitud { get; set; }

        // Auditoría
        public DateTime? FechaRegistro { get; set; }
        public DateTime? FechaActualizacion { get; set; }

        // Galería de imágenes
        public List<GaleriaLocal>? Galeria { get; set; }
    }
}
