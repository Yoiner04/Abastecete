using BusinessLogic.Models;
using BusinessLogic.Utilidades;
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
    public class ManejadorUsuario
    {
        private Connection conexion = new Connection();

        public bool RegistrarUsuario(Usuario usuario)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_nombre", usuario.Persona.Nombre),
                new Parametro("p_apellido", usuario.Persona.Apellido),
                new Parametro("p_documento", usuario.Persona.Documento),
                new Parametro("p_fk_tipo_documento", usuario.Persona.TipoDeDocumento),
                new Parametro("p_telefono", usuario.Persona.Telefono),
                new Parametro("p_correo", usuario.Correo),
                new Parametro("p_contrasenia", Seguridad.Encriptar(usuario.Contrasenia)),
                new Parametro("p_codigo_referido_usuario", usuario.CodigoReferido),
                new Parametro("p_fk_id_metodo_autenticacion", 1)
            };
            return conexion.EjecutarTransaccion("crear_usuario_persona", parametros);
        }

        public DataTable Login(string nombreUsuario, string contrasenia)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_nombre_usuario", nombreUsuario),
                new Parametro("p_contrasenia", Seguridad.Encriptar(contrasenia))
            };
            return conexion.EjecutarConsulta("login_usuario", parametros);
        }

        public List<Usuario> ObtenerUsuarios(int id)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id_persona", id)
            };
            DataTable data = conexion.EjecutarConsulta("consultar_usuario", parametros);
            List<Usuario> usuarios = new List<Usuario>();
            foreach (DataRow row in data.AsEnumerable())
            {
                usuarios.Add(new Usuario()
                {
                    Id = Convert.ToInt32(row["PK_ID_USUARIO"].ToString()),
                    Correo = row["NOMBRE_USUARIO"].ToString(),
                    Rol = new Rol()
                    {
                        Nombre = row["NOMBRE_ROL"].ToString()
                    },
                    Persona = new Persona()
                    {
                        Id = Convert.ToInt32(row["PK_ID_PERSONA"].ToString()),
                        Nombre = row["NOMBRES"].ToString(),
                        Apellido = row["APELLIDOS"].ToString(),
                        Documento = Convert.ToInt32(row["DOCUMENTO_IDENTIDAD"].ToString()),
                        Telefono = row["TELEFONO"].ToString()
                    }
                });
            }
            return usuarios;
        }

        public DataTable LoginGoogle(string correo)
        {
            List<Parametro> parametros = new List<Parametro>()
    {
        new Parametro("p_correo", correo)
    };

            return conexion.EjecutarConsulta("login_usuario_google", parametros);
        }

        // 🔹 Método optimizado para registrar usuarios autenticados con Google
        public int RegistrarUsuarioGoogle(string correo, string nombre)
        {
            try
            {
                List<Parametro> parametros = new List<Parametro>()
        {
            new Parametro("p_full_name", nombre),
            new Parametro("p_correo", correo),
            new Parametro("p_fk_id_metodo_autenticacion", 2),
            new Parametro("p_fk_id_rol", 3)
        };

                // 🔹 Intentar registrar al usuario
                bool registroExitoso = conexion.EjecutarTransaccion("crear_usuario_google", parametros);

                if (!registroExitoso)
                {
                    return 0;
                }

                // 🔹 Volver a consultar la BD para obtener el ID del usuario registrado
                DataTable data = LoginGoogle(correo);

                if (data.Rows.Count > 0)
                {
                    return Convert.ToInt32(data.Rows[0]["PK_ID_USUARIO"]);
                }
                else
                {
                    return 0;
                }
            }
            catch (Exception ex)
            {
                return 0;
            }
        }


    }
}