using BusinessLogic.Models;
using DataAccess;
using MySql.Data.MySqlClient;
using System;
using System.Collections.Generic;
using System.Data;

namespace BusinessLogic
{
    public class ManejadorMembresias
    {
        private Connection conexion;

        public ManejadorMembresias()
        {
            conexion = new Connection();
        }

        public List<Membresia> consultarTiposMembresia()
        {
            DataTable datos = conexion.EjecutarConsulta("consultar_tipo_membresia_distinct");
            List<Membresia> membresias = new List<Membresia>();
            foreach (DataRow row in datos.Rows)
            {
                membresias.Add(new Membresia
                {
                    Nombre = row["Membresia"] + ""
                });
            }
            return membresias;
        }

        public List<Membresia> ConsultarMembresias(string nombre)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("nombre", nombre)
            };

            DataTable datos = conexion.EjecutarConsulta("consultar_tipo_membresia", parametros);
            List<Membresia> membresias = new List<Membresia>();

            foreach (DataRow row in datos.Rows)
            {
                membresias.Add(new Membresia
                {
                    Id = Convert.ToInt32(row["PK_ID_TIPO_MEMBRESIA"]),
                    Nombre = row["NOMBRE"].ToString(),
                    Descripcion = row["DESCRIPCION"].ToString(),
                    Costo = float.Parse(row["COSTO"].ToString()),
                    Estado = Convert.ToInt32(row["ESTADO"]),
                    Costo_trimestral = float.Parse(row["COSTO_TRIMESTRAL"].ToString()),
                    Costo_semestral = float.Parse(row["COSTO_SEMESTRAL"].ToString()),
                    Costo_anual = float.Parse(row["COSTO_ANUAL"].ToString())
                });
            }
            return membresias;
        }

        // Editar membresía
        public string EditarMembresia(Membresia membresia)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_tipo_membresia", membresia.Id),
                new Parametro("p_nombre", membresia.Nombre),
                new Parametro("p_descripcion", membresia.Descripcion),
                new Parametro("p_costo", membresia.Costo),
                new Parametro("p_estado", membresia.Estado),
                new Parametro("p_duracion", membresia.Duracion),
                new Parametro("p_cantidad", membresia.Cantidad),
                new Parametro("p_costo_trimestral", membresia.Costo_trimestral),
                new Parametro("p_costo_semestral", membresia.Costo_semestral),
                new Parametro("p_costo_anual", membresia.Costo_anual)
            };

            bool resultado = conexion.EjecutarTransaccion("editar_tipo_membresia", parametros);
            return resultado ? "Membresía actualizada correctamente" : "Error en la base de datos";
        }

        // Obtener una membresía por ID
        public Membresia ObtenerMembresia(int id)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("id_membresia", id)
            };

            DataTable datos = conexion.EjecutarConsulta("consultar_tipo_membresia_por_id", parametros);
            if (datos.Rows.Count > 0)
            {
                DataRow row = datos.Rows[0];
                return new Membresia
                {
                    Id = Convert.ToInt32(row["PK_ID_TIPO_MEMBRESIA"]),
                    Nombre = row["NOMBRE"].ToString(),
                    Descripcion = row["DESCRIPCION"].ToString(),
                    Costo = float.Parse(row["COSTO"].ToString()),
                    Estado = Convert.ToInt32(row["ESTADO"]),
                    Duracion = Convert.ToInt32(row["DURACION_OFERTA"]),
                    Cantidad = Convert.ToInt32(row["CANTIDAD_PRODUCTOS"]),
                    Costo_trimestral = float.Parse(row["COSTO_TRIMESTRAL"].ToString()),
                    Costo_semestral = float.Parse(row["COSTO_SEMESTRAL"].ToString()),
                    Costo_anual = float.Parse(row["COSTO_ANUAL"].ToString())
                };
            }

            return null;
        }

    }
}