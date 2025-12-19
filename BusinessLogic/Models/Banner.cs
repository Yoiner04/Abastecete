namespace BusinessLogic.Models
{
    /// <summary>
    /// Modelo para banners almacenados en MySQL con imágenes en Cloudinary
    /// </summary>
    public class Banner
    {
        public int Id { get; set; }
        public string CloudinaryUrl { get; set; }
        public string CloudinaryPublicId { get; set; }
        public string Nombre { get; set; }
        public string Tipo { get; set; }  // proveedores, inicio, categoria, sesion, ofertas
        public string Formato { get; set; }  // 16:9 o 1:1
        public int? CategoriaId { get; set; }
        public bool Activo { get; set; }
        public DateTime FechaRegistro { get; set; }
    }
}
