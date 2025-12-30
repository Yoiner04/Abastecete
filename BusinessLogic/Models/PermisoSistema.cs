using System;

namespace BusinessLogic.Models
{
    /// <summary>
    /// Representa un permiso del sistema (tanto de admin como de negocio)
    /// </summary>
    public class PermisoSistema
    {
        public int Id { get; set; }

        /// <summary>
        /// Código único para verificar en código (ej: "ADMIN_USUARIOS", "PRODUCTOS_BASICO")
        /// </summary>
        public string Codigo { get; set; } = "";

        /// <summary>
        /// Nombre para mostrar en UI
        /// </summary>
        public string Nombre { get; set; } = "";

        /// <summary>
        /// Descripción del permiso
        /// </summary>
        public string Descripcion { get; set; } = "";

        /// <summary>
        /// Icono FontAwesome (ej: "fa-users")
        /// </summary>
        public string Icono { get; set; } = "";

        /// <summary>
        /// Categoría del permiso (ADMIN, PRODUCTOS, OFERTAS, ANALITICAS, MARKETING, COMUNICACION, NEGOCIO)
        /// </summary>
        public string Categoria { get; set; } = "";

        /// <summary>
        /// Orden de visualización dentro de la categoría
        /// </summary>
        public int Orden { get; set; }

        /// <summary>
        /// Estado del permiso (true = activo)
        /// </summary>
        public bool Estado { get; set; }

        // Propiedades adicionales para usuario_permiso

        /// <summary>
        /// Origen del permiso: ADMIN, MEMBRESIA, PROMOCION
        /// </summary>
        public string Origen { get; set; } = "";

        /// <summary>
        /// Fecha en que se asignó el permiso
        /// </summary>
        public DateTime? FechaAsignacion { get; set; }
    }
}
