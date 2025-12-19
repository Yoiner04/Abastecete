using System;

namespace BusinessLogic.Models
{
    /// <summary>
    /// Representa una suscripción de membresía asociada a un local.
    /// Estados: 1=Activa, 0=Inactiva, 2=Cancelada, 3=Vencida
    /// </summary>
    public class Suscripcion
    {
        public int Id { get; set; }
        public int LocalId { get; set; }
        public Membresia TipoMembresia { get; set; }
        public int Estado { get; set; }
        public DateTime FechaInicio { get; set; }
        public DateTime FechaFin { get; set; }
        public DateTime FechaCreacion { get; set; }
        public decimal? MontoPagado { get; set; }
        public string MetodoPago { get; set; }
        public string Periodo { get; set; }
        public string Notas { get; set; }

        /// <summary>
        /// Indica si la suscripción está activa y no ha vencido
        /// </summary>
        public bool EstaActiva => Estado == 1 && FechaFin > DateTime.Now;

        /// <summary>
        /// Días restantes de la suscripción
        /// </summary>
        public int DiasRestantes => EstaActiva ? (int)(FechaFin - DateTime.Now).TotalDays : 0;

        /// <summary>
        /// Indica si la suscripción está próxima a vencer (menos de 7 días)
        /// </summary>
        public bool ProximaAVencer => EstaActiva && DiasRestantes <= 7;

        /// <summary>
        /// Descripción del estado en texto
        /// </summary>
        public string EstadoDescripcion => Estado switch
        {
            0 => "Inactiva",
            1 => "Activa",
            2 => "Cancelada",
            3 => "Vencida",
            _ => "Desconocido"
        };
    }
}
