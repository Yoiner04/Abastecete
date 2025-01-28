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

    public class ManejadorPermisos
    {
        private Connection conexion = new Connection();

        public List<Permiso> ObtenerPermisos(int idRol)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id_rol", idRol)
            };
            DataTable data = conexion.EjecutarConsulta("consultar_permiso", parametros);

            List<Permiso> permisos = new List<Permiso>();
            foreach (DataRow row in data.AsEnumerable())
            {
                permisos.Add(new Permiso()
                {
                    Id = Convert.ToInt32(row["PK_ID_PERMISO"].ToString()),
                    Nombre = row["NOMBRE_PERMISO"].ToString(),
                    Estado = string.IsNullOrEmpty(row["ESTADO_PERMISO_ROL"].ToString())? false : row["ESTADO_PERMISO_ROL"].ToString() == "1"
                });
            }
            return permisos;
        }

        public bool AsignarPermiso(int idRol, int idPermiso)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id_rol", idRol),
                new Parametro("p_id_permiso", idPermiso)
            };
            return conexion.EjecutarTransaccion("asignar_permiso_rol", parametros);
        }
    }
}
