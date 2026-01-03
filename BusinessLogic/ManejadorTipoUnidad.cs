using BusinessLogic.Models;
using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;

namespace BusinessLogic
{
    public class ManejadorTipoUnidad : Interfaces.IManejadorTipoUnidad
    {
        private Connection conexion = new Connection();

        /// <summary>
        /// Consulta todos los tipos de unidad
        /// </summary>
        public List<TipoUnidad> ConsultarTiposUnidad()
        {
            DataTable data = conexion.EjecutarConsulta("consultar_tipos_unidad", new List<Parametro>());
            var tipos = new List<TipoUnidad>();
            foreach (DataRow row in data.Rows)
            {
                tipos.Add(new TipoUnidad
                {
                    Id = Convert.ToInt32(row["ID_TIPOUNIDAD"]),
                    Nombre = row["NOMBRE_TIPOUNIDAD"].ToString() ?? ""
                });
            }
            return tipos;
        }

        /// <summary>
        /// Consulta un tipo de unidad por ID
        /// </summary>
        public TipoUnidad ConsultarTipoUnidadPorId(int id)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id", id)
            };
            DataTable data = conexion.EjecutarConsulta("consultar_tipo_unidad_por_id", parametros);

            if (data.Rows.Count > 0)
            {
                DataRow row = data.Rows[0];
                return new TipoUnidad
                {
                    Id = Convert.ToInt32(row["ID_TIPOUNIDAD"]),
                    Nombre = row["NOMBRE_TIPOUNIDAD"].ToString() ?? ""
                };
            }
            return null!;
        }

        /// <summary>
        /// Crea un nuevo tipo de unidad
        /// </summary>
        public string CrearTipoUnidad(TipoUnidad tipoUnidad)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_nombre", tipoUnidad.Nombre)
            };

            var mensaje = new Parametro("mensaje", DBNull.Value);
            parametros.Add(mensaje);

            bool resultado = conexion.EjecutarTransaccion("crear_tipo_unidad", parametros);
            return resultado ? "Tipo de unidad creado exitosamente" : "Error al crear el tipo de unidad";
        }

        /// <summary>
        /// Actualiza un tipo de unidad existente
        /// </summary>
        public string EditarTipoUnidad(TipoUnidad tipoUnidad)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id", tipoUnidad.Id),
                new Parametro("p_nombre", tipoUnidad.Nombre)
            };

            var mensaje = new Parametro("mensaje", DBNull.Value);
            parametros.Add(mensaje);

            bool resultado = conexion.EjecutarTransaccion("editar_tipo_unidad", parametros);
            return resultado ? "Tipo de unidad actualizado exitosamente" : "Error al actualizar el tipo de unidad";
        }

        /// <summary>
        /// Elimina un tipo de unidad
        /// </summary>
        public (bool exito, string mensaje) EliminarTipoUnidad(int id)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id", id)
            };

            var mensaje = new Parametro("mensaje", DBNull.Value);
            parametros.Add(mensaje);

            bool resultado = conexion.EjecutarTransaccion("eliminar_tipo_unidad", parametros);
            return (resultado, resultado ? "Tipo de unidad eliminado exitosamente" : "Error al eliminar el tipo de unidad");
        }
    }
}
