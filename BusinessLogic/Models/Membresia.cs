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
        public float Costo { get; set; }
        public int Estado { get; set; }

        // Límites configurables
        public int Duracion { get; set; }  // Duración de ofertas flash en horas
        public int Cantidad { get; set; }  // Límite de productos (0=ilimitado)
        public int OfertasFlashSimultaneas { get; set; }  // Ofertas activas al mismo tiempo
        public int OfertasFlashTotal { get; set; }  // Total por suscripción (0=ilimitado)

        // Costos por período
        public float Costo_trimestral { get; set; }
        public float Costo_semestral { get; set; }
        public float Costo_anual { get; set; }

        // Descripción generada automáticamente
        public string Descripcion => GenerarDescripcion();

        private string GenerarDescripcion()
        {
            var partes = new List<string>();

            partes.Add(Cantidad == 0 ? "Productos ilimitados" : $"Hasta {Cantidad} productos");
            partes.Add($"Ofertas flash de {Duracion}h");
            partes.Add(OfertasFlashSimultaneas == 1 ? "1 oferta activa" : $"{OfertasFlashSimultaneas} ofertas activas");

            if (OfertasFlashTotal > 0)
                partes.Add($"{OfertasFlashTotal} ofertas/mes");
            else
                partes.Add("Ofertas ilimitadas");

            return string.Join(" • ", partes);
        }
    }
}
