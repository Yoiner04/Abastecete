namespace BusinessLogic.Models
{
    /// <summary>
    /// ViewModel que combina información del usuario con su local y suscripción
    /// </summary>
    public class UsuarioConLocalViewModel
    {
        public Usuario Usuario { get; set; }
        public Negocio Local { get; set; }

        // Propiedades de conveniencia
        public bool TieneLocal => Local != null;
        public bool TieneSuscripcion => Local?.SuscripcionActiva != null;
        public string NombreMembresia => Local?.SuscripcionActiva?.TipoMembresia?.Nombre ?? "Sin membresía";
        public int DiasRestantes => Local?.SuscripcionActiva?.DiasRestantes ?? 0;
        public bool SuscripcionActiva => Local?.SuscripcionActiva?.EstaActiva ?? false;
        public bool ProximaAVencer => Local?.SuscripcionActiva?.ProximaAVencer ?? false;
    }
}
