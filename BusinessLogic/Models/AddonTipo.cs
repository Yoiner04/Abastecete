namespace BusinessLogic.Models
{
    /// <summary>
    /// Representa un tipo de addon disponible para comprar
    /// </summary>
    public class AddonTipo
    {
        public int Id { get; set; }

        /// <summary>
        /// Código único del addon (ej: "ADDON_PRODUCTOS_50")
        /// </summary>
        public string Codigo { get; set; }

        /// <summary>
        /// Nombre para mostrar (ej: "+50 Productos")
        /// </summary>
        public string Nombre { get; set; }

        /// <summary>
        /// Descripción del addon
        /// </summary>
        public string Descripcion { get; set; }

        /// <summary>
        /// Tipo de límite que afecta: PRODUCTOS, OFERTAS_FLASH, DURACION_OFERTA
        /// </summary>
        public string TipoLimite { get; set; }

        /// <summary>
        /// Cantidad que agrega (ej: 50 productos)
        /// </summary>
        public int Cantidad { get; set; }

        /// <summary>
        /// Precio del addon en pesos
        /// </summary>
        public decimal Precio { get; set; }

        /// <summary>
        /// Icono FontAwesome
        /// </summary>
        public string Icono { get; set; }

        /// <summary>
        /// Estado del addon (true = disponible)
        /// </summary>
        public bool Estado { get; set; }
    }
}
