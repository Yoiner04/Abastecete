using BusinessLogic.Models;
using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;

namespace BusinessLogic
{
    public class ManejadorUnidad
    {
        private Connection conexion = new Connection();

        /// <summary>
        /// Consulta las unidades disponibles para un producto específico (basado en su tipo de unidad)
        /// </summary>
        public List<Unidad> ConsultarUnidades(int id_producto)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("id_producto", id_producto)
            };
            DataTable data = conexion.EjecutarConsulta("consultar_unidad", parametros);
            var unidades = new List<Unidad>();
            foreach (DataRow row in data.Rows)
            {
                unidades.Add(new Unidad
                {
                    Id = Convert.ToInt32(row["ID_UNIDAD"]),
                    Nombre = row["NOMBRE_UNIDAD"].ToString(),
                    Estado = Convert.ToInt32(row["ESTADO_UNIDAD"])
                });
            }
            return unidades;
        }

        /// <summary>
        /// Consulta todas las unidades del sistema
        /// </summary>
        public List<Unidad> ConsultarTodasUnidades()
        {
            DataTable data = conexion.EjecutarConsulta("consultar_todas_unidades", new List<Parametro>());
            var unidades = new List<Unidad>();
            foreach (DataRow row in data.Rows)
            {
                unidades.Add(new Unidad
                {
                    Id = Convert.ToInt32(row["ID_UNIDAD"]),
                    Nombre = row["NOMBRE_UNIDAD"].ToString(),
                    Estado = Convert.ToInt32(row["ESTADO_UNIDAD"]),
                    IdTipoUnidad = row["FK_ID_TIPOUNIDAD"] != DBNull.Value ? Convert.ToInt32(row["FK_ID_TIPOUNIDAD"]) : null,
                    NombreTipoUnidad = row["NOMBRE_TIPOUNIDAD"]?.ToString()
                });
            }
            return unidades;
        }

        /// <summary>
        /// Consulta una unidad por su ID
        /// </summary>
        public Unidad ConsultarUnidadPorId(int id)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id", id)
            };
            DataTable data = conexion.EjecutarConsulta("consultar_unidad_por_id", parametros);

            if (data.Rows.Count > 0)
            {
                DataRow row = data.Rows[0];
                return new Unidad
                {
                    Id = Convert.ToInt32(row["ID_UNIDAD"]),
                    Nombre = row["NOMBRE_UNIDAD"].ToString(),
                    Estado = Convert.ToInt32(row["ESTADO_UNIDAD"]),
                    IdTipoUnidad = row["FK_ID_TIPOUNIDAD"] != DBNull.Value ? Convert.ToInt32(row["FK_ID_TIPOUNIDAD"]) : null,
                    NombreTipoUnidad = row["NOMBRE_TIPOUNIDAD"]?.ToString()
                };
            }
            return null;
        }

        /// <summary>
        /// Consulta unidades filtradas por tipo
        /// </summary>
        public List<Unidad> ConsultarUnidadesPorTipo(int tipoUnidadId)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_tipo_unidad_id", tipoUnidadId)
            };
            DataTable data = conexion.EjecutarConsulta("consultar_unidades_por_tipo", parametros);
            var unidades = new List<Unidad>();
            foreach (DataRow row in data.Rows)
            {
                unidades.Add(new Unidad
                {
                    Id = Convert.ToInt32(row["ID_UNIDAD"]),
                    Nombre = row["NOMBRE_UNIDAD"].ToString(),
                    Estado = Convert.ToInt32(row["ESTADO_UNIDAD"]),
                    IdTipoUnidad = row["FK_ID_TIPOUNIDAD"] != DBNull.Value ? Convert.ToInt32(row["FK_ID_TIPOUNIDAD"]) : null,
                    NombreTipoUnidad = row["NOMBRE_TIPOUNIDAD"]?.ToString()
                });
            }
            return unidades;
        }

        /// <summary>
        /// Crea una nueva unidad
        /// </summary>
        public string CrearUnidad(Unidad unidad)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_nombre", unidad.Nombre),
                new Parametro("p_estado", unidad.Estado),
                new Parametro("p_tipo_unidad_id", unidad.IdTipoUnidad ?? (object)DBNull.Value)
            };

            var mensaje = new Parametro("mensaje", DBNull.Value);
            parametros.Add(mensaje);

            bool resultado = conexion.EjecutarTransaccion("crear_unidad", parametros);
            return resultado ? "Unidad creada exitosamente" : "Error al crear la unidad";
        }

        /// <summary>
        /// Actualiza una unidad existente
        /// </summary>
        public string EditarUnidad(Unidad unidad)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id", unidad.Id),
                new Parametro("p_nombre", unidad.Nombre),
                new Parametro("p_estado", unidad.Estado),
                new Parametro("p_tipo_unidad_id", unidad.IdTipoUnidad ?? (object)DBNull.Value)
            };

            var mensaje = new Parametro("mensaje", DBNull.Value);
            parametros.Add(mensaje);

            bool resultado = conexion.EjecutarTransaccion("editar_unidad", parametros);
            return resultado ? "Unidad actualizada exitosamente" : "Error al actualizar la unidad";
        }

        /// <summary>
        /// Elimina una unidad
        /// </summary>
        public (bool exito, string mensaje) EliminarUnidad(int id)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id", id)
            };

            var mensaje = new Parametro("mensaje", DBNull.Value);
            parametros.Add(mensaje);

            bool resultado = conexion.EjecutarTransaccion("eliminar_unidad", parametros);
            return (resultado, resultado ? "Unidad eliminada exitosamente" : "Error al eliminar la unidad");
        }
    }
}
