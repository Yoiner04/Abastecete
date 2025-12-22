namespace BusinessLogic.Models
{
    /// <summary>
    /// Modelo para la relación muchos a muchos entre producto y marca
    /// Permite que un producto tenga múltiples marcas con precios diferentes
    /// </summary>
    public class ProductoMarca
    {
        public int Id { get; set; }
        public int IdLocal { get; set; }
        public int IdProducto { get; set; }
        public int IdMarca { get; set; }
        public string NombreMarca { get; set; }
        public string LogoMarca { get; set; }
        public decimal Precio { get; set; }
        public int Stock { get; set; }
        public bool Disponible { get; set; }
        public DateTime FechaRegistro { get; set; }
        public DateTime FechaActualizacion { get; set; }
    }
}
