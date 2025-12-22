using BusinessLogic.Models;
using DataAccess;
using MySql.Data.MySqlClient;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BusinessLogic
{
    public class ManejadorPersonas
    {
        private Connection conexion = new Connection();

        public bool CrearPersona(Persona persona)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_nombre", persona.Nombre),
                new Parametro("p_apellido", persona.Apellido),
                new Parametro("p_documento", persona.Documento),
                new Parametro("p_telefono", persona.Telefono),
                new Parametro("p_estado", "1")
            };
            return conexion.EjecutarTransaccion("crear_persona", parametros);
        }

        public List<Persona> ObtenerPersonas(int id)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id_persona", id)
            };
            DataTable data = conexion.EjecutarConsulta("consultar_persona", parametros);
            List<Persona> personas = new List<Persona>();
            foreach (DataRow row in data.AsEnumerable())
            {
                personas.Add(new Persona()
                {
                    Id = Convert.ToInt32(row["PK_ID_PERSONA"].ToString()),
                    Nombre = row["NOMBRES"].ToString(),
                    Apellido = row["APELLIDOS"].ToString(),
                    Correo = row["CORREO"].ToString(),
                    Telefono = row["TELEFONO"].ToString(),
                    Documento = Convert.ToInt64(row["DOCUMENTO_IDENTIDAD"].ToString()),
                    Estado = row["ESTADO"].ToString()
                });
            }
            return personas;
        }

    }
}
