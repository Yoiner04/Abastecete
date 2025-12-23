using DataAccess;
using BusinessLogic.Models;
using System.Data;

namespace BusinessLogic
{
    /// <summary>
    /// Manejador para operaciones CRUD de marcas
    /// </summary>
    public class ManejadorMarcas
    {
        private readonly Connection conexion;

        public ManejadorMarcas()
        {
            conexion = new Connection();
        }

        /// <summary>
        /// Obtiene todas las marcas activas
        /// </summary>
        public List<Marca> ConsultarMarcas()
        {
            var marcas = new List<Marca>();
            var datos = conexion.EjecutarConsulta("consultar_marcas");

            foreach (DataRow row in datos.Rows)
            {
                marcas.Add(MapearMarca(row));
            }

            return marcas;
        }

        /// <summary>
        /// Obtiene todas las marcas (incluye inactivas)
        /// </summary>
        public List<Marca> ConsultarMarcasTodas()
        {
            var marcas = new List<Marca>();
            var datos = conexion.EjecutarConsulta("consultar_marcas_todas");

            foreach (DataRow row in datos.Rows)
            {
                marcas.Add(MapearMarca(row));
            }

            return marcas;
        }

        /// <summary>
        /// Obtiene una marca por ID
        /// </summary>
        public Marca ObtenerMarca(int id)
        {
            var parametros = new List<Parametro>
            {
                new Parametro("p_id", id)
            };

            var datos = conexion.EjecutarConsulta("consultar_marca_por_id", parametros);

            if (datos.Rows.Count > 0)
            {
                return MapearMarca(datos.Rows[0]);
            }

            return null;
        }

        /// <summary>
        /// Crea una nueva marca
        /// </summary>
        /// <returns>Tupla con (ID de la marca creada, mensaje)</returns>
        public (int Id, string Mensaje) CrearMarca(string nombre, string descripcion, string logoUrl, string cloudinaryPublicId)
        {
            var parametros = new List<Parametro>
            {
                new Parametro("p_nombre", nombre),
                new Parametro("p_descripcion", descripcion ?? ""),
                new Parametro("p_logo_url", logoUrl ?? ""),
                new Parametro("p_cloudinary_public_id", cloudinaryPublicId ?? "")
            };

            // El SP retorna SELECT resultado, mensaje
            var datos = conexion.EjecutarConsulta("crear_marca", parametros);

            if (datos != null && datos.Rows.Count > 0)
            {
                var row = datos.Rows[0];
                int resultado = Convert.ToInt32(row["resultado"]);
                string mensaje = row["mensaje"]?.ToString() ?? "";

                return (resultado, mensaje);
            }

            return (0, "Error al crear marca");
        }

        /// <summary>
        /// Actualiza una marca existente
        /// </summary>
        public (bool Success, string Mensaje) EditarMarca(int id, string nombre, string descripcion, string logoUrl, string cloudinaryPublicId)
        {
            var parametros = new List<Parametro>
            {
                new Parametro("p_id", id),
                new Parametro("p_nombre", nombre),
                new Parametro("p_descripcion", descripcion ?? ""),
                new Parametro("p_logo_url", logoUrl),
                new Parametro("p_cloudinary_public_id", cloudinaryPublicId),
                new Parametro("mensaje", null),
                new Parametro("resultado", null)
            };

            var resultado = conexion.EjecutarTransaccion("editar_marca", parametros);
            return (resultado, resultado ? "Marca actualizada exitosamente" : "Error al actualizar marca");
        }

        /// <summary>
        /// Elimina o desactiva una marca
        /// </summary>
        /// <returns>Tupla con (éxito, mensaje, publicId para eliminar de Cloudinary)</returns>
        public (bool Success, string Mensaje, string PublicId) EliminarMarca(int id)
        {
            // Primero obtenemos el public ID para poder eliminar de Cloudinary
            var marca = ObtenerMarca(id);
            var publicId = marca?.CloudinaryPublicId;

            var parametros = new List<Parametro>
            {
                new Parametro("p_id", id),
                new Parametro("mensaje", null),
                new Parametro("resultado", null),
                new Parametro("public_id", null)
            };

            var resultado = conexion.EjecutarTransaccion("eliminar_marca", parametros);
            return (resultado, resultado ? "Marca eliminada exitosamente" : "Error al eliminar marca", publicId);
        }

        /// <summary>
        /// Activa una marca desactivada
        /// </summary>
        public (bool Success, string Mensaje) ActivarMarca(int id)
        {
            var parametros = new List<Parametro>
            {
                new Parametro("p_id", id),
                new Parametro("mensaje", null),
                new Parametro("resultado", null)
            };

            var resultado = conexion.EjecutarTransaccion("activar_marca", parametros);
            return (resultado, resultado ? "Marca activada exitosamente" : "Error al activar marca");
        }

        /// <summary>
        /// Mapea un DataRow a un objeto Marca
        /// </summary>
        private Marca MapearMarca(DataRow row)
        {
            return new Marca
            {
                Id = Convert.ToInt32(row["PK_ID_MARCA"]),
                Nombre = row["NOMBRE"]?.ToString() ?? "",
                Descripcion = row["DESCRIPCION"]?.ToString() ?? "",
                LogoUrl = row["LOGO_URL"]?.ToString() ?? "",
                CloudinaryPublicId = row["CLOUDINARY_PUBLIC_ID"]?.ToString() ?? "",
                Activo = Convert.ToBoolean(row["ACTIVO"]),
                FechaRegistro = row["FECHA_REGISTRO"] != DBNull.Value
                    ? Convert.ToDateTime(row["FECHA_REGISTRO"])
                    : DateTime.Now
            };
        }
    }
}
