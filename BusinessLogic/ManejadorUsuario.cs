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
                new Parametro("p_fk_tipo_documento", usuario.Persona.TipoDeDocumento.Id),
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


        /*Revisar por favor*/
        public List<Usuario> ObtenerUsuarios(int id)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("id_usuario", id)
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

        public List<Usuario> ConsultarUsuarios(int idUsuario)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("id_usuario", idUsuario)
            };

            DataTable datos = conexion.EjecutarConsulta("consultar_usuarios", parametros);
            List<Usuario> usuarios = new List<Usuario>();

            foreach (DataRow row in datos.Rows)
            {
                usuarios.Add(new Usuario
                {
                    Id = Convert.ToInt32(row["PK_ID_USUARIO"]),
                    Persona = new Persona
                    {
                        Nombre = row["NOMBRES"].ToString(),
                        Apellido = row["APELLIDOS"].ToString(),
                        Telefono = row["TELEFONO"].ToString(),
                        Estado = Convert.ToInt32(row["ESTADO"]) == 1 ? "Activo" : "Inactivo",
                        Correo = row["CORREO"].ToString()
                    },
                    Rol = new Rol
                    {
                        Nombre = row["NOMBRE_ROL"].ToString()
                    },
                    Correo = row["CORREO"].ToString(),
                    CodigoReferido = 0,
                    Membresia = row["NOMBRE"].ToString() // Aquí va el nombre de la membresía directamente
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

                bool registroExitoso = conexion.EjecutarTransaccion("crear_usuario_google", parametros);

                if (!registroExitoso)
                {
                    return 0;
                }

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

        public DataTable ObtenerUsuarioPorCorreo(string correo)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_correo", correo)
            };

            return conexion.EjecutarConsulta("obtener_usuario_por_correo", parametros);
        }


        public void GenerarTokenRecuperacion(int userId)
        {
            bool resultado = conexion.EjecutarTransaccion("generar_token_recuperacion", new List<Parametro>
            {
                new Parametro("p_fk_id_usuario", userId)
            });
        }




        public string ObtenerTokenRecuperacion(int userId)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_fk_id_usuario", userId)
            };

            DataTable data = conexion.EjecutarConsulta("obtener_token_recuperacion", parametros);

            if (data == null || data.Rows.Count == 0 || string.IsNullOrEmpty(data.Rows[0]["TOKEN_RECUPERACION"].ToString()))
            {
                return null;
            }

            string token = data.Rows[0]["TOKEN_RECUPERACION"].ToString();
            return token;
        }

        public DataTable ValidarTokenRecuperacion(string token)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_token", token)
            };

            return conexion.EjecutarConsulta("validar_token_recuperacion", parametros);
        }


        public bool ValidarToken(string token, out int userId)
        {
            userId = 0;

            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_token", token)
            };

            DataTable data = conexion.EjecutarConsulta("validar_token_recuperacion", parametros);

            if (data.Rows.Count > 0)
            {
                if (data.Columns.Contains("PK_ID_USUARIO"))
                {
                    userId = Convert.ToInt32(data.Rows[0]["PK_ID_USUARIO"]);
                    return true;
                }
            }

            return false;
        }



        public bool CambiarContrasenia(int userId, string nuevaContrasenia)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_usuario", userId),
                new Parametro("p_nueva_contrasenia", Seguridad.Encriptar(nuevaContrasenia))
            };

            return conexion.EjecutarTransaccion("recuperar_contrasenia", parametros);
        }




        public bool EditarEstadoUsuario(int idUsuario, int nuevoEstado)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_usuario", idUsuario),
                new Parametro("p_estado", nuevoEstado)
            };

            try
            {
                bool resultado = conexion.EjecutarTransaccion("editar_estado_usuario", parametros);
                return resultado;
            }
            catch (Exception ex)
            {
                return false;
            }
        }

    }
}