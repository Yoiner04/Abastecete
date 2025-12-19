namespace BusinessLogic.Models
{
    /// <summary>
    /// Modelo para marcas de productos
    /// </summary>
    public class Marca
    {
        public int Id { get; set; }
        public string Nombre { get; set; }
        public string Descripcion { get; set; }
        public string LogoUrl { get; set; }
        public string CloudinaryPublicId { get; set; }
        public bool Activo { get; set; }
        public DateTime FechaRegistro { get; set; }

        /// <summary>
        /// Cantidad de productos asociados (para mostrar en lista)
        /// </summary>
        public int CantidadProductos { get; set; }
    }
}
