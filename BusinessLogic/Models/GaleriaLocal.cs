using System;

namespace BusinessLogic.Models
{
    public class GaleriaLocal
    {
        public int Id { get; set; }
        public int LocalId { get; set; }
        public string CloudinaryUrl { get; set; }
        public string? CloudinaryPublicId { get; set; }
        public EstadoGaleria Estado { get; set; }
        public DateTime FechaSubida { get; set; }
        public DateTime? FechaRevision { get; set; }
        public int? UsuarioRevisorId { get; set; }
        public string? MotivoRechazo { get; set; }

        // Propiedades adicionales para vistas
        public string? NombreLocal { get; set; }
        public string? PropietarioNombre { get; set; }
        public string? PropietarioApellido { get; set; }

        public string EstadoDescripcion => Estado switch
        {
            EstadoGaleria.Pendiente => "Pendiente",
            EstadoGaleria.Aprobada => "Aprobada",
            EstadoGaleria.Rechazada => "Rechazada",
            _ => "Desconocido"
        };

        public string EstadoClase => Estado switch
        {
            EstadoGaleria.Pendiente => "bg-yellow-100 text-yellow-800",
            EstadoGaleria.Aprobada => "bg-green-100 text-green-800",
            EstadoGaleria.Rechazada => "bg-red-100 text-red-800",
            _ => "bg-gray-100 text-gray-800"
        };

        public string EstadoIcono => Estado switch
        {
            EstadoGaleria.Pendiente => "fa-clock",
            EstadoGaleria.Aprobada => "fa-check",
            EstadoGaleria.Rechazada => "fa-times",
            _ => "fa-question"
        };
    }

    public enum EstadoGaleria
    {
        Pendiente = 0,
        Aprobada = 1,
        Rechazada = 2
    }
}
