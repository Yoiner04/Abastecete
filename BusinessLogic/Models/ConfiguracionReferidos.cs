using System;

namespace BusinessLogic.Models
{
    public class ConfiguracionReferidos
    {
        public int Id { get; set; }
        public string TipoDescuentoReferido { get; set; } = "PORCENTAJE";
        public decimal ValorDescuentoReferido { get; set; } = 10;
        public string TipoDescuentoDueno { get; set; } = "PORCENTAJE";
        public decimal ValorDescuentoDueno { get; set; } = 10;
        public bool DescuentoActivo { get; set; } = true;
        public DateTime? FechaActualizacion { get; set; }
        public int? ActualizadoPor { get; set; }
    }

    public class ValidacionCodigo
    {
        public bool Valido { get; set; }
        public string Mensaje { get; set; } = "";
        public int IdDueno { get; set; }
        public string NombreDueno { get; set; } = "";
    }

    public class CalculoDescuento
    {
        public decimal DescuentoReferido { get; set; }
        public decimal CreditoDisponible { get; set; }
        public bool YaUsoDescuento { get; set; }
        public string CodigoUsado { get; set; } = "";
        public string TipoDescuento { get; set; } = "";
        public decimal ValorConfigurado { get; set; }
        public decimal MontoFinal { get; set; }
    }

    public class ResumenReferidos
    {
        public string CodigoReferido { get; set; } = "";
        public int TotalReferidos { get; set; }
        public int ReferidosCompraron { get; set; }
        public decimal CreditoTotalGanado { get; set; }
        public decimal CreditoDisponible { get; set; }
    }
}
