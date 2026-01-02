using System;

namespace BusinessLogic.Models
{
    /// <summary>
    /// Representa los límites y uso actual de una membresía para un local
    /// </summary>
    public class LimitesMembresia
    {
        // Estado de la suscripción
        public bool TieneSuscripcionActiva { get; set; }
        public int DiasRestantes { get; set; }
        public DateTime? FechaVencimiento { get; set; }
        public string NombreMembresia { get; set; } = "";

        // Límites configurados
        public int LimiteProductos { get; set; }
        public int LimiteOfertasSimultaneas { get; set; }
        public int LimiteOfertasTotal { get; set; }
        public int DuracionOfertaHoras { get; set; }

        // Uso actual
        public int ProductosActuales { get; set; }
        public int OfertasActivas { get; set; }
        public int OfertasUsadasPeriodo { get; set; }

        // Permisos calculados
        public bool PuedeAgregarProductos { get; set; }
        public bool PuedeCrearOferta { get; set; }

        // Propiedades calculadas para la UI
        public bool ProductosIlimitados => LimiteProductos == 0;
        public bool OfertasIlimitadas => LimiteOfertasTotal == 0;

        public int ProductosDisponibles => ProductosIlimitados ? int.MaxValue : Math.Max(0, LimiteProductos - ProductosActuales);
        public int OfertasSimultaneasDisponibles => Math.Max(0, LimiteOfertasSimultaneas - OfertasActivas);
        public int OfertasTotalDisponibles => OfertasIlimitadas ? int.MaxValue : Math.Max(0, LimiteOfertasTotal - OfertasUsadasPeriodo);

        public double PorcentajeProductosUsados => LimiteProductos > 0 ? (double)ProductosActuales / LimiteProductos * 100 : 0;
        public double PorcentajeOfertasUsadas => LimiteOfertasTotal > 0 ? (double)OfertasUsadasPeriodo / LimiteOfertasTotal * 100 : 0;

        public bool ProximoAVencer => TieneSuscripcionActiva && DiasRestantes <= 7;
        public bool MembresiaVencida => !TieneSuscripcionActiva || DiasRestantes < 0;

        /// <summary>
        /// Texto para mostrar el uso de productos (ej: "5/10" o "5/Ilimitado")
        /// </summary>
        public string TextoUsoProductos => ProductosIlimitados
            ? $"{ProductosActuales}/Ilimitado"
            : $"{ProductosActuales}/{LimiteProductos}";

        /// <summary>
        /// Texto para mostrar el uso de ofertas simultáneas
        /// </summary>
        public string TextoOfertasActivas => $"{OfertasActivas}/{LimiteOfertasSimultaneas}";

        /// <summary>
        /// Texto para mostrar el uso de ofertas en el período
        /// </summary>
        public string TextoOfertasPeriodo => OfertasIlimitadas
            ? $"{OfertasUsadasPeriodo}/Ilimitado"
            : $"{OfertasUsadasPeriodo}/{LimiteOfertasTotal}";
    }

    /// <summary>
    /// Resultado de validación de límite de productos
    /// </summary>
    public class ValidacionProducto
    {
        public bool PuedeAgregar { get; set; }
        public int ProductosActuales { get; set; }
        public int LimiteMaximo { get; set; }
        public string Mensaje { get; set; } = "";

        public bool LimiteIlimitado => LimiteMaximo == 0;
        public int Disponibles => LimiteIlimitado ? int.MaxValue : Math.Max(0, LimiteMaximo - ProductosActuales);
    }

    /// <summary>
    /// Resultado de validación de límite de ofertas flash
    /// </summary>
    public class ValidacionOferta
    {
        public bool PuedeCrear { get; set; }
        public string Mensaje { get; set; } = "";
        public int OfertasActivas { get; set; }
        public int LimiteSimultaneas { get; set; }
        public int OfertasUsadas { get; set; }
        public int LimiteTotal { get; set; }
        public int DuracionHoras { get; set; }
    }
}
