using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;
using BusinessLogic.Models;

namespace BusinessLogic
{
    public class ManejadorNegocios
    {
        private Connection conexion;

        public ManejadorNegocios()
        {
            conexion = new Connection();
        }

        public bool CrearNegocio(Negocio negocio)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_fk_id_persona", negocio.Persona.Nombre),
                new Parametro("p_fk_id_estado_local", negocio.Estado),
                new Parametro("p_barrio_local", negocio.Nombre),
                new Parametro("p_nombre_local", negocio.Nombre),
                new Parametro("p_direccion_local", negocio.Direccion),
                new Parametro("p_telefono_local", negocio.Telefono),
                new Parametro("p_fotos_local", negocio.Logotipo)
            };

            return conexion.EjecutarTransaccion("crear_persona", parametros);
        }

        public List<Negocio> ConsultarNegocios()
        {
            DataTable datos = conexion.EjecutarConsulta("consultar_local");
            List<Negocio> negocios = new List<Negocio>();

            foreach (DataRow row in datos.Rows)
            {
                negocios.Add(new Negocio
                {
                    Id = Convert.ToInt32(row["PK_ID_LOCAL"].ToString()),
                    Nombre = row["NOMBRE_LOCAL"].ToString()
                });
            }
            return negocios;
        }

    }
}
