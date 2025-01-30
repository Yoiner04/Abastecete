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
    public class ManejadorRoles
    {
        private Connection conexion = new Connection();

        public bool CrearRol(Rol rol)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_nombre", rol.Nombre)
            };
            return conexion.EjecutarTransaccion("crear_rol", parametros);
        }

        public List<Rol> ObtenerRoles()
        {

            DataTable data = conexion.EjecutarConsulta("consultar_rol");
            List<Rol> roles = new List<Rol>();
            foreach (DataRow row in data.AsEnumerable())
            {
                roles.Add(new Rol()
                {
                    Id = Convert.ToInt32(row["PK_ID_ROL"].ToString()),
                    Nombre = row["NOMBRE_ROL"].ToString(),
                });
            }
            return roles;
        }

        public bool AsignarRol(int idRol, int idUsuario)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id_usuario", idUsuario),
                new Parametro("p_id_rol", idRol)
            };
            return conexion.EjecutarTransaccion("asignar_rol", parametros);
        }

    }
}
