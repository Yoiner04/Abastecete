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
    public class ManejadorUsuario : Interfaces.IManejadorUsuario
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
                new Parametro("p_nombres", usuario.Nombres),
                new Parametro("p_apellidos", usuario.Apellidos),
                new Parametro("p_telefono", usuario.Telefono),
                new Parametro("p_correo", usuario.Correo),
                new Parametro("p_contrasenia", Seguridad.Encriptar(usuario.Contrasenia)),
                new Parametro("p_documento", usuario.DocumentoIdentidad),
                new Parametro("p_fk_tipo_documento", usuario.TipoDocumentoId > 0 ? usuario.TipoDocumentoId : 1),
                new Parametro("p_fk_rol", usuario.RolId > 0 ? usuario.RolId : 3),
                new Parametro("p_codigo_referido_usado", usuario.CodigoReferidoUsado ?? ""),
            };
            return conexion.EjecutarTransaccionConMensaje("crear_usuario", parametros);
        }

        public DataTable Login(string nombreUsuario, string contrasenia)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_nombre_usuario", nombreUsuario),
                new Parametro("p_contrasenia", "") // No se usa, pero el SP lo requiere
            };

            var result = conexion.EjecutarConsulta("login_usuario", parametros);

            if (result.Rows.Count > 0)
            {
                // CODIGO_ESTADO: 97=inhabilitado, 98=no existe, 0=bloqueado, 1=OK
                int codigoEstado = Convert.ToInt32(result.Rows[0]["CODIGO_ESTADO"]);

                // Si es código de error (97, 98, 0), retornar directamente
                if (codigoEstado == 97 || codigoEstado == 98 || codigoEstado == 0)
                {
                    return result;
                }

                // Verificar contraseña con BCrypt
                if (result.Columns.Contains("CONTRASENIA_HASH") && result.Rows[0]["CONTRASENIA_HASH"] != DBNull.Value)
                {
                    string hashAlmacenado = result.Rows[0]["CONTRASENIA_HASH"]?.ToString() ?? "";
                    bool contraseniaValida = Seguridad.VerificarContrasenia(contrasenia, hashAlmacenado);

                    if (contraseniaValida)
                    {
                        // Limpiar intentos fallidos
                        int idUsuario = Convert.ToInt32(result.Rows[0]["PK_ID_USUARIO"]);
                        LimpiarIntentosFallidos(idUsuario);
                        return result;
                    }
                    else
                    {
                        // Contraseña incorrecta - registrar intento fallido
                        int idUsuario = Convert.ToInt32(result.Rows[0]["PK_ID_USUARIO"]);
                        RegistrarIntentoFallido(idUsuario);

                        // Retornar código 99 (contraseña incorrecta)
                        DataTable errorResult = new DataTable();
                        errorResult.Columns.Add("CODIGO_ESTADO", typeof(int));
                        errorResult.Rows.Add(99);
                        return errorResult;
                    }
                }
            }

            return result;
        }

        private void RegistrarIntentoFallido(int idUsuario)
        {
            try
            {
                var parametros = new List<Parametro>()
                {
                    new Parametro("p_id_usuario", idUsuario)
                };
                conexion.EjecutarTransaccion("registrar_intento_fallido", parametros);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[LOGIN] Error registrando intento fallido: {ex.Message}");
            }
        }

        private void LimpiarIntentosFallidos(int idUsuario)
        {
            try
            {
                var parametros = new List<Parametro>()
                {
                    new Parametro("p_id_usuario", idUsuario)
                };
                conexion.EjecutarTransaccion("limpiar_intentos_fallidos", parametros);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[LOGIN] Error limpiando intentos fallidos: {ex.Message}");
            }
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
                usuarios.Add(MapearUsuario(row));
            }
            return usuarios;
        }

        /// <summary>
        /// Mapea un DataRow a un objeto Usuario
        /// </summary>
        private Usuario MapearUsuario(DataRow row)
        {
            string correo = DataRowHelper.GetString(row, "CORREO");
            if (string.IsNullOrEmpty(correo))
                correo = DataRowHelper.GetString(row, "NOMBRE_USUARIO");

            return new Usuario
            {
                Id = DataRowHelper.GetInt(row, "PK_ID_USUARIO"),
                Nombres = DataRowHelper.GetString(row, "NOMBRES"),
                Apellidos = DataRowHelper.GetString(row, "APELLIDOS"),
                FotoPerfil = DataRowHelper.GetString(row, "FOTO_PERFIL"),
                Telefono = DataRowHelper.GetString(row, "TELEFONO"),
                Correo = correo,
                Estado = DataRowHelper.GetInt(row, "ESTADO", 1),
                DocumentoIdentidad = DataRowHelper.GetLongNullable(row, "DOCUMENTO_IDENTIDAD"),
                TipoDocumentoId = DataRowHelper.GetInt(row, "FK_ID_TIPO_DOCUMENTO", 1),
                CodigoReferido = DataRowHelper.GetString(row, "CODIGO_REFERIDO"),
                Rol = new Rol
                {
                    Nombre = "" // Ya no usamos roles, se usa sistema de permisos por membresía
                },
                RolId = 0 // Obsoleto - se usa sistema de permisos por membresía
            };
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

        public int RegistrarUsuarioGoogle(string correo, string nombre, string? fotoUrl = null)
        {
            try
            {
                List<Parametro> parametros = new List<Parametro>()
                {
                    new Parametro("p_email", correo),
                    new Parametro("p_nombre", nombre),
                    new Parametro("p_foto_url", fotoUrl ?? "")
                };

                DataTable resultado = conexion.EjecutarConsulta("sp_registrar_usuario_google", parametros);

                if (resultado != null && resultado.Rows.Count > 0)
                {
                    return Convert.ToInt32(resultado.Rows[0]["IdUsuario"]);
                }

                return 0;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[GOOGLE REGISTRO] Error: {ex.Message}");
                return 0;
            }
        }

        /// <summary>
        /// Actualiza la foto de perfil de un usuario (desde Google OAuth)
        /// </summary>
        public bool ActualizarFotoPerfil(int idUsuario, string fotoUrl)
        {
            try
            {
                var parametros = new List<Parametro>
                {
                    new Parametro("p_id_usuario", idUsuario),
                    new Parametro("p_foto_url", fotoUrl)
                };

                DataTable resultado = conexion.EjecutarConsulta("sp_actualizar_foto_perfil", parametros);
                return resultado != null && resultado.Rows.Count > 0 && Convert.ToInt32(resultado.Rows[0]["Actualizado"]) > 0;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[FOTO PERFIL] Error: {ex.Message}");
                return false;
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




        public string? ObtenerTokenRecuperacion(int userId)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_fk_id_usuario", userId)
            };

            DataTable data = conexion.EjecutarConsulta("obtener_token_recuperacion", parametros);

            if (data == null || data.Rows.Count == 0 || string.IsNullOrEmpty(data.Rows[0]["TOKEN_RECUPERACION"]?.ToString()))
            {
                return null;
            }

            string? token = data.Rows[0]["TOKEN_RECUPERACION"]?.ToString();
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

        /// <summary>
        /// Cambia la contraseña del usuario verificando la contraseña actual
        /// </summary>
        public (bool exito, string mensaje) CambiarContraseniaVerificada(int userId, string contraseniaActual, string nuevaContrasenia)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_usuario", userId),
                new Parametro("p_contrasenia_actual", Seguridad.Encriptar(contraseniaActual)),
                new Parametro("p_nueva_contrasenia", Seguridad.Encriptar(nuevaContrasenia))
            };

            return conexion.EjecutarTransaccionConMensaje("cambiar_contrasenia_verificada", parametros);
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
            catch
            {
                return false;
            }
        }


        public bool EditarUsuario(Usuario usuario)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_usuario", usuario.Id),
                new Parametro("p_nombres", usuario.Nombres),
                new Parametro("p_apellidos", usuario.Apellidos),
                new Parametro("p_telefono", usuario.Telefono),
            };
            bool act = conexion.EjecutarTransaccion("editar_usuario", parametros);
            return act;
        }

        /// <summary>
        /// Obtiene usuarios con información de su local y suscripción
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

                // Intentar obtener el local del usuario
                if (usuario.Id > 0)
                {
                    viewModel.Local = manejadorNegocios.ConsultarNegocioUsuarioConSuscripcion(usuario.Id);
                }

                resultado.Add(viewModel);
            }

            return resultado;
        }

        /// <summary>
        /// Consulta usuarios paginados con información de local y suscripción en una sola query
        /// </summary>
        public ResultadoPaginado<UsuarioConLocalViewModel> ConsultarUsuariosPaginado(int pagina, int registrosPorPagina, string? busqueda = null)
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
                        Nombres = row["Nombres"]?.ToString() ?? "",
                        Apellidos = row["Apellidos"]?.ToString() ?? "",
                        Telefono = row["Telefono"]?.ToString() ?? "",
                        Correo = row["Correo"]?.ToString() ?? "",
                        Estado = Convert.ToInt32(row["UsuarioEstado"]),
                        Rol = new Rol
                        {
                            Nombre = row["RolNombre"]?.ToString() ?? ""
                        }
                    }
                };

                // Local y suscripción (si existen)
                if (row["LocalId"] != DBNull.Value)
                {
                    viewModel.Local = new Negocio
                    {
                        Id = Convert.ToInt32(row["LocalId"]),
                        Nombre = row["LocalNombre"]?.ToString() ?? ""
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
                                Nombre = row["TipoMembresiaNombre"]?.ToString() ?? ""
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
