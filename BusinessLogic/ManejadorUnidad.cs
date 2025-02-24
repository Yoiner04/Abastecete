using BusinessLogic.Models;
using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BusinessLogic
{
    public class ManejadorUnidad
    {
        private Connection conexion = new Connection();

        public List<Unidad> ConsultarUnidades()
        {
            DataTable data = conexion.EjecutarConsulta("consultar_unidad");
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
