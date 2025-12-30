using System;

namespace BusinessLogic.Models
{
    public class Referido
    {
        public int Id { get; set; }
        public int IdUsuarioReferido { get; set; }
        public string Nombres { get; set; } = "";
        public string Apellidos { get; set; } = "";
        public string NombreCompleto => $"{Nombres} {Apellidos}".Trim();
        public DateTime FechaRegistro { get; set; }
        public DateTime? FechaCompra { get; set; }
        public decimal? MontoCompra { get; set; }
        public decimal? CreditoRecibido { get; set; }
        public string? MembresiaComprada { get; set; }
        public bool HaComprado { get; set; }
    }
}
