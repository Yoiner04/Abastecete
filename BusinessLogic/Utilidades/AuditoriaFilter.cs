using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using BusinessLogic.Models;
using System;
using System.Linq;

namespace BusinessLogic.Utilidades
{
    /// <summary>
    /// Atributo para marcar acciones que deben ser auditadas automáticamente.
    /// Uso: [Auditar(ModulosAuditoria.PRODUCTOS, TiposAccionAuditoria.CREATE)]
    /// </summary>
    [AttributeUsage(AttributeTargets.Method | AttributeTargets.Class, AllowMultiple = false)]
    public class AuditarAttribute : ActionFilterAttribute
    {
        private readonly string _modulo;
        private readonly string _tipoAccion;

        /// <summary>
        /// Nombre del parámetro que contiene el ID de la entidad
        /// </summary>
        public string ParametroId { get; set; } = "id";

        /// <summary>
        /// Nombre del parámetro que contiene la descripción/nombre de la entidad
        /// </summary>
        public string ParametroDescripcion { get; set; } = "nombre";

        public AuditarAttribute(string modulo, string tipoAccion)
        {
            _modulo = modulo;
            _tipoAccion = tipoAccion;
        }

        public override void OnActionExecuting(ActionExecutingContext context)
        {
            // Capturar parámetros antes de la ejecución para usarlos después
            foreach (var arg in context.ActionArguments)
            {
                context.HttpContext.Items[$"Auditoria_{arg.Key}"] = arg.Value;
            }

            base.OnActionExecuting(context);
        }

        public override void OnActionExecuted(ActionExecutedContext context)
        {
            try
            {
                var httpContext = context.HttpContext;
                var manejadorLogs = new ManejadorLogs();

                // Obtener información del usuario de la sesión
                var usuarioId = httpContext.Session.GetInt32("idUsuario");
                var nombreUsuario = httpContext.Session.GetString("nombreUsuario");

                // Si no hay nombre de usuario, intentar obtener el nombre completo
                if (string.IsNullOrEmpty(nombreUsuario))
                {
                    var nombres = httpContext.Session.GetString("nombres");
                    var apellidos = httpContext.Session.GetString("apellidos");
                    nombreUsuario = $"{nombres} {apellidos}".Trim();

                    if (string.IsNullOrEmpty(nombreUsuario) && usuarioId.HasValue)
                    {
                        nombreUsuario = $"Usuario ID: {usuarioId}";
                    }
                }

                // Obtener IP del cliente
                var ipCliente = ObtenerIpCliente(httpContext);
                var userAgent = httpContext.Request.Headers["User-Agent"].FirstOrDefault() ?? "";

                // Obtener información de la entidad desde los parámetros capturados
                int? entidadId = ObtenerValorParametro<int?>(httpContext, ParametroId);
                string entidadDescripcion = ObtenerValorParametro<string>(httpContext, ParametroDescripcion) ?? "";

                // Determinar resultado de la acción
                string resultado = "EXITO";
                string? mensajeError = null;

                // Analizar el resultado de la acción
                if (context.Exception != null)
                {
                    resultado = "ERROR";
                    mensajeError = context.Exception.Message;
                }
                else if (context.Result is JsonResult jsonResult && jsonResult.Value != null)
                {
                    var value = jsonResult.Value;
                    var valueType = value.GetType();

                    // Buscar propiedad success o exito
                    var successProp = valueType.GetProperty("success") ?? valueType.GetProperty("exito");
                    if (successProp != null)
                    {
                        var success = successProp.GetValue(value);
                        if (success is bool boolSuccess && !boolSuccess)
                        {
                            resultado = "ERROR";
                            var mensajeProp = valueType.GetProperty("mensaje") ?? valueType.GetProperty("message");
                            mensajeError = mensajeProp?.GetValue(value)?.ToString();
                        }
                    }

                    // Obtener ID de entidad creada si aplica
                    if (_tipoAccion == TiposAccionAuditoria.CREATE && !entidadId.HasValue)
                    {
                        var idProp = valueType.GetProperty("id") ?? valueType.GetProperty("Id");
                        if (idProp != null)
                        {
                            var idValue = idProp.GetValue(value);
                            if (idValue != null && int.TryParse(idValue.ToString(), out int newId))
                            {
                                entidadId = newId;
                            }
                        }
                    }
                }
                else if (context.Result is BadRequestObjectResult || context.Result is BadRequestResult)
                {
                    resultado = "ERROR";
                    mensajeError = "Solicitud incorrecta";
                }

                // Obtener nombre del controller y action
                string controllerName = "";
                string actionName = "";

                if (context.ActionDescriptor is Microsoft.AspNetCore.Mvc.Controllers.ControllerActionDescriptor descriptor)
                {
                    controllerName = descriptor.ControllerName;
                    actionName = descriptor.ActionName;
                }

                // Registrar el log
                manejadorLogs.RegistrarLog(
                    usuarioId,
                    nombreUsuario ?? "Anónimo",
                    _modulo,
                    _tipoAccion,
                    entidadId,
                    entidadDescripcion,
                    null, // datosAnteriores - se puede extender para capturar
                    null, // datosNuevos - se puede extender para capturar
                    ipCliente,
                    userAgent,
                    resultado,
                    mensajeError,
                    controllerName,
                    actionName
                );
            }
            catch (Exception ex)
            {
                // No debe fallar la acción por un error de logging
                Console.WriteLine($"Error en AuditoriaFilter: {ex.Message}");
            }

            base.OnActionExecuted(context);
        }

        private string ObtenerIpCliente(HttpContext context)
        {
            // Primero intentar X-Forwarded-For (proxy/load balancer)
            var forwardedFor = context.Request.Headers["X-Forwarded-For"].FirstOrDefault();
            if (!string.IsNullOrEmpty(forwardedFor))
            {
                return forwardedFor.Split(',').First().Trim();
            }

            // Luego X-Real-IP
            var realIp = context.Request.Headers["X-Real-IP"].FirstOrDefault();
            if (!string.IsNullOrEmpty(realIp))
            {
                return realIp;
            }

            // Finalmente la IP directa
            return context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        }

        private T ObtenerValorParametro<T>(HttpContext context, string nombreParametro)
        {
            // Buscar en los items guardados durante OnActionExecuting
            if (context.Items.TryGetValue($"Auditoria_{nombreParametro}", out var valor))
            {
                if (valor is T typedValue)
                    return typedValue;

                // Intentar conversión
                if (valor != null)
                {
                    try
                    {
                        var targetType = typeof(T);
                        var underlyingType = Nullable.GetUnderlyingType(targetType) ?? targetType;

                        if (underlyingType == typeof(int))
                        {
                            if (int.TryParse(valor.ToString(), out int intVal))
                                return (T)(object)intVal;
                        }
                        else if (underlyingType == typeof(string))
                        {
                            return (T)(object)(valor.ToString() ?? "");
                        }
                    }
                    catch { }
                }
            }

            // Buscar en propiedades de objetos complejos (ej: model.Id, model.Nombre)
            foreach (var item in context.Items)
            {
                if (item.Key?.ToString()?.StartsWith("Auditoria_") == true && item.Value != null)
                {
                    var objValue = item.Value;
                    var prop = objValue.GetType().GetProperty(nombreParametro) ??
                               objValue.GetType().GetProperty(char.ToUpper(nombreParametro[0]) + nombreParametro.Substring(1));

                    if (prop != null)
                    {
                        var propValue = prop.GetValue(objValue);
                        if (propValue is T typedPropValue)
                            return typedPropValue;

                        if (propValue != null)
                        {
                            try
                            {
                                return (T)Convert.ChangeType(propValue, Nullable.GetUnderlyingType(typeof(T)) ?? typeof(T));
                            }
                            catch { }
                        }
                    }
                }
            }

            return default!;
        }
    }
}
