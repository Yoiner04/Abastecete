namespace BusinessLogic.Models
{
    /// <summary>
    /// Modelo para opiniones/reseñas de locales
    /// </summary>
    public class Opinion
    {
        public int Id { get; set; }
        public int IdLocal { get; set; }
        public int IdUsuario { get; set; }
        public int? IdOpinionPadre { get; set; }
        public int Calificacion { get; set; }
        public string? Comentario { get; set; }
        public DateTime FechaOpinion { get; set; }
        public string? RespuestaDueno { get; set; }
        public DateTime? FechaRespuesta { get; set; }
        public int Estado { get; set; }

        // Datos del usuario que opinó
        public string? NombreUsuario { get; set; }
        public string? FotoUsuario { get; set; }

        // Datos del local (para "mis opiniones")
        public string? NombreLocal { get; set; }
        public string? FotoLocal { get; set; }

        // Cantidad de respuestas a esta opinión
        public int CantidadRespuestas { get; set; }

        // Lista de respuestas (para cargar hilos)
        public List<Opinion>? Respuestas { get; set; }
    }

    /// <summary>
    /// Resumen de calificaciones de un local
    /// </summary>
    public class ResumenOpiniones
    {
        public int TotalOpiniones { get; set; }
        public decimal PromedioCalificacion { get; set; }
        public int Estrellas5 { get; set; }
        public int Estrellas4 { get; set; }
        public int Estrellas3 { get; set; }
        public int Estrellas2 { get; set; }
        public int Estrellas1 { get; set; }
        public int TotalConCalificacion { get; set; }
    }

    /// <summary>
    /// DTO para crear una opinión
    /// </summary>
    public class CrearOpinionDto
    {
        public int IdLocal { get; set; }
        public int Calificacion { get; set; }
        public string? Comentario { get; set; }
        public int? IdOpinionPadre { get; set; }
    }

    /// <summary>
    /// Resultado de verificar si usuario ya puntuó
    /// </summary>
    public class VerificacionPuntuacion
    {
        public bool YaPuntuo { get; set; }
        public int CalificacionDada { get; set; }
    }
}
