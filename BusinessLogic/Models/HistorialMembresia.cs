using System;

namespace BusinessLogic.Models
{
    /// <summary>
    /// Representa un registro del historial de cambios de membresía de un local.
    /// Tipos de cambio: ALTA, UPGRADE, DOWNGRADE, RENOVACION, CANCELACION, VENCIMIENTO, MIGRACION
    /// </summary>
    public class HistorialMembresia
    {
        public int Id { get; set; }
        public int LocalId { get; set; }
        public int? SuscripcionId { get; set; }
        public Membresia? TipoAnterior { get; set; }
        public Membresia? TipoNuevo { get; set; }
        public string TipoCambio { get; set; } = "";
        public DateTime FechaCambio { get; set; }
        public DateTime FechaInicioPeriodo { get; set; }
        public DateTime FechaFinPeriodo { get; set; }
        public decimal? Monto { get; set; }
        public string Periodo { get; set; } = "";
        public string? Notas { get; set; }

        /// <summary>
        /// Descripción legible del tipo de cambio
        /// </summary>
        public string TipoCambioDescripcion => TipoCambio switch
        {
            "ALTA" => "Alta inicial",
            "UPGRADE" => "Mejora de plan",
            "DOWNGRADE" => "Reducción de plan",
            "RENOVACION" => "Renovación",
            "CANCELACION" => "Cancelación",
            "VENCIMIENTO" => "Vencimiento",
            "MIGRACION" => "Migración de datos",
            _ => TipoCambio
        };

        /// <summary>
        /// Icono CSS para el tipo de cambio
        /// </summary>
        public string TipoCambioIcono => TipoCambio switch
        {
            "ALTA" => "fa-plus-circle text-green-600",
            "UPGRADE" => "fa-arrow-up text-blue-600",
            "DOWNGRADE" => "fa-arrow-down text-orange-600",
            "RENOVACION" => "fa-sync-alt text-purple-600",
            "CANCELACION" => "fa-times-circle text-red-600",
            "VENCIMIENTO" => "fa-clock text-gray-600",
            "MIGRACION" => "fa-database text-gray-400",
            _ => "fa-circle text-gray-400"
        };
    }
}
