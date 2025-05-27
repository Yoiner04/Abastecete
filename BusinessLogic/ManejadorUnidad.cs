using BusinessLogic.Models;
using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using static System.Runtime.InteropServices.JavaScript.JSType;

namespace BusinessLogic
{
    public class ManejadorUnidad
    {
        private Connection conexion = new Connection();

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
    }
}
