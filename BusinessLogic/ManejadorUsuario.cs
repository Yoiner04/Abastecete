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
            var resultado = RegistrarUsuarioConMensaje(usuario);
            return resultado.exito;
        }

        public (bool exito, string mensaje) RegistrarUsuarioConMensaje(Usuario usuario)
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
            return conexion.EjecutarTransaccionConMensaje("crear_usuario_persona", parametros);
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
                        Id = row["PK_ID_PERSONA"] != DBNull.Value ? Convert.ToInt32(row["PK_ID_PERSONA"]) : 0,
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
                    CodigoReferido = null
                });
            }
            return usuarios;
        }

        /// <summary>
        /// Alias de ConsultarUsuarios para compatibilidad
        /// </summary>
        public List<Usuario> ObtenerUsuarios(int idUsuario) => ConsultarUsuarios(idUsuario);



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

        
        public bool EditarUsuario(Persona usuario)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_nombre", usuario.Nombre),
                new Parametro("p_apellido", usuario.Apellido),
                new Parametro("p_documento", usuario.Documento),
                new Parametro("p_fk_tipo_documento", usuario.TipoDeDocumento.Id),
                new Parametro("p_telefono", usuario.Telefono),
                new Parametro("p_correo", usuario.Correo),
            };
            bool act = conexion.EjecutarTransaccion("editar_usuario_persona", parametros);
            return act;
        }

        /// <summary>
        /// Obtiene usuarios con información de su local y suscripción (método legacy - usa N+1 queries)
        /// </summary>
        public List<UsuarioConLocalViewModel> ConsultarUsuariosConLocal(int idUsuario)
        {
            var usuarios = ConsultarUsuarios(idUsuario);
            var manejadorNegocios = new ManejadorNegocios();
            var resultado = new List<UsuarioConLocalViewModel>();

            foreach (var usuario in usuarios)
            {
                var viewModel = new UsuarioConLocalViewModel
                {
                    Usuario = usuario
                };

                // Intentar obtener el local del usuario (por persona)
                if (usuario.Persona?.Id > 0)
                {
                    viewModel.Local = manejadorNegocios.ConsultarNegocioPersonaConSuscripcion(usuario.Persona.Id);
                }

                resultado.Add(viewModel);
            }

            return resultado;
        }

        /// <summary>
        /// Consulta usuarios paginados con información de local y suscripción en una sola query
        /// </summary>
        public ResultadoPaginado<UsuarioConLocalViewModel> ConsultarUsuariosPaginado(int pagina, int registrosPorPagina, string busqueda = null)
        {
            var resultado = new ResultadoPaginado<UsuarioConLocalViewModel>
            {
                PaginaActual = pagina,
                RegistrosPorPagina = registrosPorPagina
            };

            // Obtener total de registros
            List<Parametro> parametrosConteo = new List<Parametro>
            {
                new Parametro("p_busqueda", busqueda ?? "")
            };
            DataTable dataConteo = conexion.EjecutarConsulta("contar_usuarios", parametrosConteo);
            if (dataConteo.Rows.Count > 0)
            {
                resultado.TotalRegistros = Convert.ToInt32(dataConteo.Rows[0]["Total"]);
            }

            // Obtener registros paginados
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_pagina", pagina),
                new Parametro("p_registros_por_pagina", registrosPorPagina),
                new Parametro("p_busqueda", busqueda ?? "")
            };

            DataTable datos = conexion.EjecutarConsulta("consultar_usuarios_paginado", parametros);

            foreach (DataRow row in datos.Rows)
            {
                var viewModel = new UsuarioConLocalViewModel
                {
                    Usuario = new Usuario
                    {
                        Id = Convert.ToInt32(row["UsuarioId"]),
                        Persona = new Persona
                        {
                            Id = row["PersonaId"] != DBNull.Value ? Convert.ToInt32(row["PersonaId"]) : 0,
                            Nombre = row["PersonaNombres"].ToString(),
                            Apellido = row["PersonaApellidos"].ToString(),
                            Telefono = row["PersonaTelefono"].ToString(),
                            Correo = row["PersonaCorreo"].ToString(),
                            Estado = Convert.ToInt32(row["UsuarioEstado"]) == 1 ? "Activo" : "Inactivo"
                        },
                        Rol = new Rol
                        {
                            Nombre = row["RolNombre"].ToString()
                        },
                        Correo = row["PersonaCorreo"].ToString()
                    }
                };

                // Local y suscripción (si existen)
                if (row["LocalId"] != DBNull.Value)
                {
                    viewModel.Local = new Negocio
                    {
                        Id = Convert.ToInt32(row["LocalId"]),
                        Nombre = row["LocalNombre"].ToString()
                    };

                    // Suscripción activa (si existe)
                    if (row["SuscripcionId"] != DBNull.Value)
                    {
                        viewModel.Local.SuscripcionActiva = new Suscripcion
                        {
                            Id = Convert.ToInt32(row["SuscripcionId"]),
                            FechaInicio = row["SuscripcionFechaInicio"] != DBNull.Value
                                ? Convert.ToDateTime(row["SuscripcionFechaInicio"])
                                : DateTime.MinValue,
                            FechaFin = row["SuscripcionFechaFin"] != DBNull.Value
                                ? Convert.ToDateTime(row["SuscripcionFechaFin"])
                                : DateTime.MinValue,
                            Estado = row["SuscripcionEstado"] != DBNull.Value
                                ? Convert.ToInt32(row["SuscripcionEstado"])
                                : 0,
                            TipoMembresia = new Membresia
                            {
                                Id = row["TipoMembresiaId"] != DBNull.Value
                                    ? Convert.ToInt32(row["TipoMembresiaId"])
                                    : 0,
                                Nombre = row["TipoMembresiaNombre"].ToString()
                            }
                        };
                    }
                }

                resultado.Items.Add(viewModel);
            }

            return resultado;
        }

    }
}