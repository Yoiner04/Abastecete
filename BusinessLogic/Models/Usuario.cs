using System;

namespace BusinessLogic.Models
{
    public class Usuario
    {
        public int Id { get; set; }

        // Datos personales (antes en tabla persona)
        public string Nombres { get; set; } = "";
        public string Apellidos { get; set; } = "";
        public string Telefono { get; set; } = "";
        public long? DocumentoIdentidad { get; set; }
        public int TipoDocumentoId { get; set; }
        public string CodigoReferido { get; set; } = "";
        public string CodigoReferidoUsado { get; set; } = "";

        // Datos de cuenta
        public string Correo { get; set; } = "";  // NOMBRE_USUARIO en BD
        public string Contrasenia { get; set; } = "";
        public int Estado { get; set; }
        public bool CorreoVerificado { get; set; }

        // Seguridad
        public int IntentosFallidos { get; set; }
        public DateTime? FechaBloqueo { get; set; }
        public string? TokenRecuperacion { get; set; }
        public DateTime? FechaExpiracionToken { get; set; }
        public int IntentosRecuperacion { get; set; }
        public DateTime? FechaUltimoIntentoRecuperacion { get; set; }

        // Referidos
        public int ClientesReferidosTotal { get; set; }
        public decimal CreditoReferidos { get; set; }
        public bool YaUsoDescuentoReferido { get; set; }

        // Rol
        public Rol? Rol { get; set; }
        public int RolId { get; set; }

        // Tipo de autenticación (Google, email, etc)
        public int? TipoAutenticacion { get; set; }

        // Nombre completo (helper)
        public string NombreCompleto => $"{Nombres} {Apellidos}".Trim();
    }
}
