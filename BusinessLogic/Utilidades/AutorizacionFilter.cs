using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace BusinessLogic.Utilidades
{
    /// <summary>
    /// Filtro de autorización basado en permisos del nuevo sistema unificado
    /// Uso: [RequierePermiso("ADMIN_USUARIOS")] o [RequierePermiso("ADMIN_USUARIOS,ADMIN_PERMISOS")]
    /// </summary>
    public class RequierePermisoAttribute : ActionFilterAttribute
    {
        private readonly string _permiso;

        public RequierePermisoAttribute(string permiso)
        {
            _permiso = permiso;
        }

        public override void OnActionExecuting(ActionExecutingContext context)
        {
            // Primero intentar con el nuevo sistema de permisos
            var permisosSistema = context.HttpContext.Session.GetString("permisosSistema");

            // Si existe en el nuevo sistema, verificar ahí
            if (!string.IsNullOrEmpty(permisosSistema))
            {
                if (!RolPermisos.TienePermiso(_permiso, permisosSistema))
                {
                    context.Result = new RedirectToActionResult("Principal", "Home", null);
                }
            }
            else
            {
                // Fallback al sistema antiguo para compatibilidad
                var permisos = context.HttpContext.Session.GetString("permisos");
                if (string.IsNullOrEmpty(permisos) || !RolPermisos.TienePermiso(_permiso, permisos))
                {
                    context.Result = new RedirectToActionResult("Principal", "Home", null);
                }
            }

            base.OnActionExecuting(context);
        }
    }

    /// <summary>
    /// Filtro que requiere que el usuario esté autenticado
    /// Uso: [RequiereAutenticacion]
    /// </summary>
    public class RequiereAutenticacionAttribute : ActionFilterAttribute
    {
        public override void OnActionExecuting(ActionExecutingContext context)
        {
            var usuarioId = context.HttpContext.Session.GetInt32("idUsuario");

            if (!usuarioId.HasValue)
            {
                context.Result = new RedirectToActionResult("Login", "Login", null);
            }

            base.OnActionExecuting(context);
        }
    }

    /// <summary>
    /// Helper para validaciones de sesión
    /// </summary>
    public static class SesionHelper
    {
        public static bool EstaAutenticado(ISession session)
        {
            return session.GetInt32("idUsuario").HasValue;
        }

        public static int? ObtenerUsuarioId(ISession session)
        {
            return session.GetInt32("idUsuario");
        }

        /// <summary>
        /// Verifica si el usuario tiene un permiso específico
        /// Usa el nuevo sistema de permisos con fallback al antiguo
        /// </summary>
        public static bool TienePermiso(ISession session, string permiso)
        {
            // Primero intentar con nuevo sistema
            var permisosSistema = session.GetString("permisosSistema");
            if (!string.IsNullOrEmpty(permisosSistema))
            {
                return RolPermisos.TienePermiso(permiso, permisosSistema);
            }

            // Fallback al sistema antiguo
            var permisos = session.GetString("permisos");
            return RolPermisos.TienePermiso(permiso, permisos);
        }

        /// <summary>
        /// Verifica si el usuario es administrador (tiene algún permiso ADMIN_*)
        /// </summary>
        public static bool EsAdministrador(ISession session)
        {
            var permisosSistema = session.GetString("permisosSistema");
            if (!string.IsNullOrEmpty(permisosSistema))
            {
                return RolPermisos.EsAdministrador(permisosSistema);
            }

            // Fallback al sistema antiguo por rol
            var rolStr = session.GetString("idRol");
            if (int.TryParse(rolStr, out int rol))
            {
                return rol == 1 || rol == 8; // Admin o Director
            }
            return false;
        }

        /// <summary>
        /// Obtiene todos los permisos del usuario como lista
        /// </summary>
        public static List<string> ObtenerPermisos(ISession session)
        {
            var permisosSistema = session.GetString("permisosSistema");
            return RolPermisos.ObtenerListaPermisos(permisosSistema);
        }
    }
}
