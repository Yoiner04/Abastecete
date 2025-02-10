using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;
using BusinessLogic.Models;

namespace BusinessLogic
{
    public class ManejadorMembresias
    {
        private Connection conexion;

        public ManejadorMembresias()
        {
            conexion = new Connection();
        }

        // Consultar todas las membresías
        public List<Membresia> ConsultarMembresias()
        {
            DataTable datos = conexion.EjecutarConsulta("consultar_tipo_membresia");
            List<Membresia> membresias = new List<Membresia>();

            foreach (DataRow row in datos.Rows)
            {
                membresias.Add(new Membresia
                {
                    Id = Convert.ToInt32(row["PK_ID_TIPO_MEMBRESIA"]),
                    Nombre = row["NOMBRE"].ToString(),
                    Descripcion = row["DESCRIPCION"].ToString(),
                    Costo = Convert.ToDecimal(row["COSTO"]),
                    Estado = Convert.ToInt32(row["ESTADO"])
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
                new Parametro("p_estado", membresia.Estado)
            };

            bool resultado = conexion.EjecutarTransaccion("editar_tipo_membresia", parametros);
            return resultado ? "Membresía actualizada correctamente" : "Error en la base de datos";
        }

        // Obtener una membresía por ID
        public Membresia ObtenerMembresia(int id)
        {
            DataTable datos = conexion.EjecutarConsulta("consultar_tipo_membresia");
            DataRow row = datos.AsEnumerable().FirstOrDefault(r => Convert.ToInt32(r["PK_ID_TIPO_MEMBRESIA"]) == id);

            if (row != null)
            {
                return new Membresia
                {
                    Id = Convert.ToInt32(row["PK_ID_TIPO_MEMBRESIA"]),
                    Nombre = row["NOMBRE"].ToString(),
                    Descripcion = row["DESCRIPCION"].ToString(),
                    Costo = Convert.ToDecimal(row["COSTO"]),
                    Estado = Convert.ToInt32(row["ESTADO"])
                };
            }

            return null;
        }
    }
}