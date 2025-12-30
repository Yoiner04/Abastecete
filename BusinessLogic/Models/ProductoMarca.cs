namespace BusinessLogic.Models
{
    /// <summary>
    /// Modelo para las presentaciones de un producto
    /// Permite que un producto tenga múltiples combinaciones de marca + medida + precio
    /// Ejemplo: "Coca Cola 350ml Postobon $2,500" vs "Coca Cola 1L Postobon $5,000"
    /// </summary>
    public class ProductoMarca
    {
        public int Id { get; set; }
        public int IdLocal { get; set; }
        public int IdProducto { get; set; }

        // Marca
        public int IdMarca { get; set; }
        public string NombreMarca { get; set; } = "";
        public string? LogoMarca { get; set; }

        // Unidad/Medida (ej: 500ml, 1kg, unidad)
        public int? IdUnidad { get; set; }
        public string NombreUnidad { get; set; } = "";

        // Precio y disponibilidad
        public decimal Precio { get; set; }
        public int Stock { get; set; }
        public bool Disponible { get; set; }

        // Fechas
        public DateTime FechaRegistro { get; set; }
        public DateTime FechaActualizacion { get; set; }

        /// <summary>
        /// Descripción de la presentación para mostrar en UI
        /// Ej: "Postobon - 500ml" o "Sin marca - Unidad"
        /// </summary>
        public string DescripcionPresentacion =>
            string.IsNullOrEmpty(NombreUnidad)
                ? NombreMarca
                : $"{NombreMarca} - {NombreUnidad}";
    }
}
