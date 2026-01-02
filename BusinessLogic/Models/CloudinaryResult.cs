namespace BusinessLogic.Models
{
    /// <summary>
    /// Resultado de una operación de subida a Cloudinary
    /// </summary>
    public class CloudinaryResult
    {
        /// <summary>
        /// URL pública de la imagen
        /// </summary>
        public string Url { get; set; } = "";

        /// <summary>
        /// URL segura (HTTPS) de la imagen
        /// </summary>
        public string SecureUrl { get; set; } = "";

        /// <summary>
        /// ID público para identificar y eliminar la imagen
        /// </summary>
        public string PublicId { get; set; } = "";

        /// <summary>
        /// Indica si la operación fue exitosa
        /// </summary>
        public bool Success { get; set; }

        /// <summary>
        /// Mensaje de error si la operación falló
        /// </summary>
        public string? Error { get; set; }

        /// <summary>
        /// Ancho de la imagen en píxeles
        /// </summary>
        public int Width { get; set; }

        /// <summary>
        /// Alto de la imagen en píxeles
        /// </summary>
        public int Height { get; set; }

        /// <summary>
        /// Formato de la imagen (jpg, png, webp, etc.)
        /// </summary>
        public string Format { get; set; } = "";
    }
}
