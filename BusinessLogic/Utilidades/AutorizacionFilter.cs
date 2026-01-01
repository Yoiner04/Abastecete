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
            var permisosSistema = context.HttpContext.Session.GetString("permisosSistema") ?? "";

            if (string.IsNullOrEmpty(permisosSistema) || !RolPermisos.TienePermiso(_permiso, permisosSistema))
            {
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
                context.Result = new RedirectToActionResult("Index", "Login", null);
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
        /// </summary>
        public static bool TienePermiso(ISession session, string permiso)
        {
            var permisosSistema = session.GetString("permisosSistema") ?? "";
            return RolPermisos.TienePermiso(permiso, permisosSistema);
        }

        /// <summary>
        /// Verifica si el usuario es administrador (tiene algún permiso ADMIN_*)
        /// </summary>
        public static bool EsAdministrador(ISession session)
        {
            var permisosSistema = session.GetString("permisosSistema") ?? "";
            return RolPermisos.EsAdministrador(permisosSistema);
        }

        /// <summary>
        /// Obtiene todos los permisos del usuario como lista
        /// </summary>
        public static List<string> ObtenerPermisos(ISession session)
        {
            var permisosSistema = session.GetString("permisosSistema");
            return RolPermisos.ObtenerListaPermisos(permisosSistema ?? "");
        }
    }
}
