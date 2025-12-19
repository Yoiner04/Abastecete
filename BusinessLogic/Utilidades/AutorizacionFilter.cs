using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace BusinessLogic.Utilidades
{
    /// <summary>
    /// Filtro de autorización basado en permisos
    /// Uso: [RequierePermiso("Administrar Productos")]
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
            var permisos = context.HttpContext.Session.GetString("permisos");

            if (string.IsNullOrEmpty(permisos) || !RolPermisos.TienePermiso(_permiso, permisos))
            {
                // Redirigir a página principal si no tiene permiso
                context.Result = new RedirectToActionResult("Principal", "Home", null);
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

        public static int? ObtenerPersonaId(ISession session)
        {
            return session.GetInt32("PersonaId");
        }

        public static int? ObtenerRolId(ISession session)
        {
            var rolStr = session.GetString("idRol");
            return int.TryParse(rolStr, out int rol) ? rol : null;
        }

        public static bool TienePermiso(ISession session, string permiso)
        {
            var permisos = session.GetString("permisos");
            return RolPermisos.TienePermiso(permiso, permisos);
        }

        public static bool EsAdministrador(ISession session)
        {
            var rolId = ObtenerRolId(session);
            return rolId == 1 || rolId == 8; // Admin o Director
        }
    }
}
