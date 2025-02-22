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
                new Parametro("p_fk_id_persona", negocio.Persona.Id),
                new Parametro("p_fk_id_estado_local", 1),
                new Parametro("p_fk_id_tipomembresia", negocio.TipoMembresia),
                new Parametro("p_barrio_local", negocio.Barrio),
                new Parametro("p_nombre_local", negocio.Nombre),
                new Parametro("p_direccion_local", negocio.Direccion),
                new Parametro("p_telefono_local", negocio.Telefono),
                new Parametro("p_fotos_local", "/images/ec46cdab-e96a-4bb6-bacc-0c5b408dc97d_frutaverdura.webp")
            };
            return conexion.EjecutarTransaccion("crear_local", parametros);
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
