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
                new Parametro("p_localizacion", negocio.Localizacion),
                new Parametro("p_nombre_local", negocio.Nombre),
                new Parametro("p_direccion_local", negocio.Direccion),
                new Parametro("p_telefono_local", negocio.Telefono),
                new Parametro("p_fotos_local", "/images/ec46cdab-e96a-4bb6-bacc-0c5b408dc97d_frutaverdura.webp")
            };
            return conexion.EjecutarTransaccion("crear_local", parametros);
        }

        public Negocio ConsultarNegocio(int idPersona)
        {
            //string consulta = $"consultar_local({idPersona})";

            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_persona", idPersona)
            };

            DataTable datos = conexion.EjecutarConsulta("consultar_local", parametros);

            DataRow row = datos.Rows[0]; // Tomamos la primera fila

            return new Negocio
            {
                Id = Convert.ToInt32(row["PK_ID_LOCAL"]),
                Nombre = row["NOMBRE_LOCAL"].ToString(),
                Localizacion = row["LOCALIZACION"].ToString(),
                Telefono = Convert.ToInt64(row["TELEFONO_LOCAL"]),
                Logotipo = row["FOTOS_LOCAL"].ToString()
            };
        }

        public List<Negocio> ConsultarTodosLosNegocios()
        {
            string consulta = "consultar_local(0)";

            DataTable datos = conexion.EjecutarConsulta(consulta);
            List<Negocio> negocios = new List<Negocio>();

            foreach (DataRow row in datos.Rows)
            {
                negocios.Add(new Negocio
                {
                    Id = Convert.ToInt32(row["PK_ID_LOCAL"]),
                    Nombre = row["NOMBRE_LOCAL"].ToString(),
                    Localizacion = row["LOCALIZACION"].ToString(),
                    Telefono = Convert.ToInt32(row["TELEFONO_LOCAL"]),
                    Logotipo = row["FOTOS_LOCAL"].ToString()
                });
            }

            return negocios;
        }
    }
}
