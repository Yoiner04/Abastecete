using System;

namespace BusinessLogic.Models
{
    /// <summary>
    /// Representa un addon comprado por un local
    /// </summary>
    public class AddonLocal
    {
        public int Id { get; set; }

        public int IdLocal { get; set; }

        public int IdAddon { get; set; }

        /// <summary>
        /// Cuántas veces compró este addon
        /// </summary>
        public int CantidadComprada { get; set; }

        public DateTime FechaCompra { get; set; }

        /// <summary>
        /// Fecha de expiración (null = no expira)
        /// </summary>
        public DateTime? FechaExpiracion { get; set; }

        /// <summary>
        /// Referencia de pago (ePayco)
        /// </summary>
        public string? RefPago { get; set; }

        public bool Estado { get; set; }

        // Propiedades del addon relacionado
        public string CodigoAddon { get; set; } = "";
        public string NombreAddon { get; set; } = "";
        public string TipoLimite { get; set; } = "";
        public int CantidadAddon { get; set; }

        /// <summary>
        /// Total agregado (CantidadAddon * CantidadComprada)
        /// </summary>
        public int TotalAgregado { get; set; }
    }
}
