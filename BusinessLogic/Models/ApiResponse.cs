namespace BusinessLogic.Models
{
    /// <summary>
    /// Respuesta estándar para APIs JSON
    /// </summary>
    public class ApiResponse
    {
        public bool Success { get; set; }
        public string Mensaje { get; set; } = "";
        public object? Data { get; set; }

        public static ApiResponse Ok(string mensaje = "Operación exitosa", object? data = null)
        {
            return new ApiResponse { Success = true, Mensaje = mensaje, Data = data };
        }

        public static ApiResponse Error(string mensaje = "Error en la operación")
        {
            return new ApiResponse { Success = false, Mensaje = mensaje };
        }

        public static ApiResponse SesionExpirada()
        {
            return new ApiResponse { Success = false, Mensaje = "Sesión expirada" };
        }

        public static ApiResponse SinPermisos()
        {
            return new ApiResponse { Success = false, Mensaje = "Sin permisos para esta acción" };
        }

        public static ApiResponse DatosInvalidos(string detalle = "")
        {
            return new ApiResponse
            {
                Success = false,
                Mensaje = string.IsNullOrEmpty(detalle) ? "Datos inválidos" : $"Datos inválidos: {detalle}"
            };
        }
    }

    /// <summary>
    /// Respuesta tipada para APIs JSON
    /// </summary>
    public class ApiResponse<T>
    {
        public bool Success { get; set; }
        public string Mensaje { get; set; } = "";
        public T? Data { get; set; }

        public static ApiResponse<T> Ok(T data, string mensaje = "Operación exitosa")
        {
            return new ApiResponse<T> { Success = true, Mensaje = mensaje, Data = data };
        }

        public static ApiResponse<T> Error(string mensaje = "Error en la operación")
        {
            return new ApiResponse<T> { Success = false, Mensaje = mensaje };
        }
    }
}
