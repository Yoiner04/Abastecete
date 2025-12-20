using System;

namespace BusinessLogic.Models
{
    /// <summary>
    /// Modelo para registros de auditoría del sistema
    /// </summary>
    public class LogSistema
    {
        public int Id { get; set; }
        public int? UsuarioId { get; set; }
        public string NombreUsuario { get; set; }
        public string Modulo { get; set; }
        public string TipoAccion { get; set; }
        public int? EntidadId { get; set; }
        public string EntidadDescripcion { get; set; }
        public string DatosAnteriores { get; set; }
        public string DatosNuevos { get; set; }
        public string IpCliente { get; set; }
        public string UserAgent { get; set; }
        public DateTime FechaRegistro { get; set; }
        public string Resultado { get; set; }
        public string MensajeError { get; set; }
        public string Controller { get; set; }
        public string Action { get; set; }

        // Propiedades de presentación
        public string TipoAccionDescripcion => TipoAccion switch
        {
            "CREATE" => "Creación",
            "UPDATE" => "Actualización",
            "DELETE" => "Eliminación",
            _ => TipoAccion
        };

        public string TipoAccionIcono => TipoAccion switch
        {
            "CREATE" => "fa-plus-circle text-green-600",
            "UPDATE" => "fa-edit text-blue-600",
            "DELETE" => "fa-trash text-red-600",
            _ => "fa-circle text-gray-400"
        };

        public string ResultadoColor => Resultado == "EXITO"
            ? "bg-green-100 text-green-700"
            : "bg-red-100 text-red-700";

        public string ModuloColor => Modulo switch
        {
            "PRODUCTOS" => "bg-purple-100 text-purple-700",
            "USUARIOS" => "bg-blue-100 text-blue-700",
            "LOCALES" => "bg-orange-100 text-orange-700",
            "MEMBRESIAS" => "bg-yellow-100 text-yellow-700",
            "MARCAS" => "bg-pink-100 text-pink-700",
            "OFERTAS_FLASH" => "bg-red-100 text-red-700",
            "BANNERS" => "bg-indigo-100 text-indigo-700",
            _ => "bg-gray-100 text-gray-700"
        };
    }

    /// <summary>
    /// Módulos disponibles para logging
    /// </summary>
    public static class ModulosAuditoria
    {
        public const string PRODUCTOS = "PRODUCTOS";
        public const string USUARIOS = "USUARIOS";
        public const string LOCALES = "LOCALES";
        public const string MEMBRESIAS = "MEMBRESIAS";
        public const string MARCAS = "MARCAS";
        public const string OFERTAS_FLASH = "OFERTAS_FLASH";
        public const string BANNERS = "BANNERS";
        public const string CATEGORIAS = "CATEGORIAS";
        public const string SUBCATEGORIAS = "SUBCATEGORIAS";
        public const string ROLES = "ROLES";

        public static string[] Todos => new[]
        {
            PRODUCTOS, USUARIOS, LOCALES, MEMBRESIAS,
            MARCAS, OFERTAS_FLASH, BANNERS, CATEGORIAS
        };
    }

    /// <summary>
    /// Tipos de acción para auditoría
    /// </summary>
    public static class TiposAccionAuditoria
    {
        public const string CREATE = "CREATE";
        public const string UPDATE = "UPDATE";
        public const string DELETE = "DELETE";
    }
}
