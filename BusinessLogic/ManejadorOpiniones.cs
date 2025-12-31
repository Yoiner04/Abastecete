using System.Data;
using BusinessLogic.Models;
using DataAccess;

namespace BusinessLogic
{
    public class ManejadorOpiniones
    {
        private readonly Connection conexion;

        public ManejadorOpiniones()
        {
            conexion = new Connection();
        }

        /// <summary>
        /// Crea una nueva opinión o comentario
        /// </summary>
        public (int id, string mensaje, bool exito) CrearOpinion(int idLocal, int idUsuario, int calificacion, string? comentario, int? idOpinionPadre = null)
        {
            var parametros = new List<Parametro>
            {
                new Parametro("p_id_local", idLocal),
                new Parametro("p_id_usuario", idUsuario),
                new Parametro("p_calificacion", calificacion),
                new Parametro("p_comentario", comentario ?? ""),
                new Parametro("p_id_opinion_padre", idOpinionPadre ?? 0)
            };

            DataTable resultado = conexion.EjecutarConsulta("sp_crear_opinion", parametros);

            if (resultado != null && resultado.Rows.Count > 0)
            {
                var row = resultado.Rows[0];
                return (
                    Convert.ToInt32(row["Id"]),
                    row["Mensaje"].ToString() ?? "",
                    Convert.ToInt32(row["Exito"]) == 1
                );
            }

            return (0, "Error al procesar la solicitud", false);
        }

        /// <summary>
        /// Obtiene las opiniones principales de un local (paginado)
        /// </summary>
        public List<Opinion> ObtenerOpinionesLocal(int idLocal, int pagina = 1, int cantidad = 10)
        {
            var opiniones = new List<Opinion>();

            var parametros = new List<Parametro>
            {
                new Parametro("p_id_local", idLocal),
                new Parametro("p_pagina", pagina),
                new Parametro("p_cantidad", cantidad)
            };

            DataTable datos = conexion.EjecutarConsulta("sp_obtener_opiniones_local", parametros);

            if (datos != null)
            {
                foreach (DataRow row in datos.Rows)
                {
                    opiniones.Add(MapearOpinion(row));
                }
            }

            return opiniones;
        }

        /// <summary>
        /// Obtiene las respuestas a una opinión
        /// </summary>
        public List<Opinion> ObtenerRespuestasOpinion(int idOpinionPadre)
        {
            var respuestas = new List<Opinion>();

            var parametros = new List<Parametro>
            {
                new Parametro("p_id_opinion_padre", idOpinionPadre)
            };

            DataTable datos = conexion.EjecutarConsulta("sp_obtener_respuestas_opinion", parametros);

            if (datos != null)
            {
                foreach (DataRow row in datos.Rows)
                {
                    respuestas.Add(new Opinion
                    {
                        Id = Convert.ToInt32(row["Id"]),
                        IdLocal = Convert.ToInt32(row["IdLocal"]),
                        IdUsuario = Convert.ToInt32(row["IdUsuario"]),
                        IdOpinionPadre = Convert.ToInt32(row["IdOpinionPadre"]),
                        NombreUsuario = row["NombreUsuario"]?.ToString(),
                        FotoUsuario = row["FotoUsuario"]?.ToString(),
                        Comentario = row["Comentario"]?.ToString(),
                        FechaOpinion = Convert.ToDateTime(row["FechaOpinion"]),
                        Estado = Convert.ToInt32(row["Estado"])
                    });
                }
            }

            return respuestas;
        }

        /// <summary>
        /// Obtiene el resumen de calificaciones de un local
        /// </summary>
        public ResumenOpiniones ObtenerResumenOpiniones(int idLocal)
        {
            var parametros = new List<Parametro>
            {
                new Parametro("p_id_local", idLocal)
            };

            DataTable datos = conexion.EjecutarConsulta("sp_obtener_resumen_opiniones", parametros);

            if (datos != null && datos.Rows.Count > 0)
            {
                var row = datos.Rows[0];
                return new ResumenOpiniones
                {
                    TotalOpiniones = row["TotalOpiniones"] != DBNull.Value ? Convert.ToInt32(row["TotalOpiniones"]) : 0,
                    PromedioCalificacion = row["PromedioCalificacion"] != DBNull.Value ? Convert.ToDecimal(row["PromedioCalificacion"]) : 0,
                    Estrellas5 = row["Estrellas5"] != DBNull.Value ? Convert.ToInt32(row["Estrellas5"]) : 0,
                    Estrellas4 = row["Estrellas4"] != DBNull.Value ? Convert.ToInt32(row["Estrellas4"]) : 0,
                    Estrellas3 = row["Estrellas3"] != DBNull.Value ? Convert.ToInt32(row["Estrellas3"]) : 0,
                    Estrellas2 = row["Estrellas2"] != DBNull.Value ? Convert.ToInt32(row["Estrellas2"]) : 0,
                    Estrellas1 = row["Estrellas1"] != DBNull.Value ? Convert.ToInt32(row["Estrellas1"]) : 0,
                    TotalConCalificacion = row["TotalConCalificacion"] != DBNull.Value ? Convert.ToInt32(row["TotalConCalificacion"]) : 0
                };
            }

            return new ResumenOpiniones();
        }

        /// <summary>
        /// El dueño responde a una opinión
        /// </summary>
        public (int id, string mensaje, bool exito) ResponderOpinionDueno(int idOpinion, int idLocal, string respuesta)
        {
            var parametros = new List<Parametro>
            {
                new Parametro("p_id_opinion", idOpinion),
                new Parametro("p_id_local", idLocal),
                new Parametro("p_respuesta", respuesta)
            };

            DataTable resultado = conexion.EjecutarConsulta("sp_responder_opinion_dueno", parametros);

            if (resultado != null && resultado.Rows.Count > 0)
            {
                var row = resultado.Rows[0];
                return (
                    Convert.ToInt32(row["Id"]),
                    row["Mensaje"].ToString() ?? "",
                    Convert.ToInt32(row["Exito"]) == 1
                );
            }

            return (0, "Error al procesar la solicitud", false);
        }

        /// <summary>
        /// Verifica si un usuario ya puntuó un local
        /// </summary>
        public VerificacionPuntuacion VerificarPuntuacionUsuario(int idLocal, int idUsuario)
        {
            var parametros = new List<Parametro>
            {
                new Parametro("p_id_local", idLocal),
                new Parametro("p_id_usuario", idUsuario)
            };

            DataTable datos = conexion.EjecutarConsulta("sp_verificar_puntuacion_usuario", parametros);

            if (datos != null && datos.Rows.Count > 0)
            {
                var row = datos.Rows[0];
                return new VerificacionPuntuacion
                {
                    YaPuntuo = Convert.ToInt32(row["YaPuntuo"]) == 1,
                    CalificacionDada = Convert.ToInt32(row["CalificacionDada"])
                };
            }

            return new VerificacionPuntuacion { YaPuntuo = false, CalificacionDada = 0 };
        }

        /// <summary>
        /// Elimina una opinión (solo el usuario que la creó)
        /// </summary>
        public (int id, string mensaje, bool exito) EliminarOpinion(int idOpinion, int idUsuario)
        {
            var parametros = new List<Parametro>
            {
                new Parametro("p_id_opinion", idOpinion),
                new Parametro("p_id_usuario", idUsuario)
            };

            DataTable resultado = conexion.EjecutarConsulta("sp_eliminar_opinion", parametros);

            if (resultado != null && resultado.Rows.Count > 0)
            {
                var row = resultado.Rows[0];
                return (
                    Convert.ToInt32(row["Id"]),
                    row["Mensaje"].ToString() ?? "",
                    Convert.ToInt32(row["Exito"]) == 1
                );
            }

            return (0, "Error al procesar la solicitud", false);
        }

        /// <summary>
        /// Obtiene las opiniones de un usuario
        /// </summary>
        public List<Opinion> ObtenerMisOpiniones(int idUsuario)
        {
            var opiniones = new List<Opinion>();

            var parametros = new List<Parametro>
            {
                new Parametro("p_id_usuario", idUsuario)
            };

            DataTable datos = conexion.EjecutarConsulta("sp_obtener_mis_opiniones", parametros);

            if (datos != null)
            {
                foreach (DataRow row in datos.Rows)
                {
                    opiniones.Add(new Opinion
                    {
                        Id = Convert.ToInt32(row["Id"]),
                        IdLocal = Convert.ToInt32(row["IdLocal"]),
                        NombreLocal = row["NombreLocal"]?.ToString(),
                        FotoLocal = row["FotoLocal"]?.ToString(),
                        Calificacion = Convert.ToInt32(row["Calificacion"]),
                        Comentario = row["Comentario"]?.ToString(),
                        FechaOpinion = Convert.ToDateTime(row["FechaOpinion"]),
                        RespuestaDueno = row["RespuestaDueno"]?.ToString(),
                        FechaRespuesta = row["FechaRespuesta"] != DBNull.Value
                            ? Convert.ToDateTime(row["FechaRespuesta"])
                            : null,
                        IdOpinionPadre = row["IdOpinionPadre"] != DBNull.Value
                            ? Convert.ToInt32(row["IdOpinionPadre"])
                            : null
                    });
                }
            }

            return opiniones;
        }

        /// <summary>
        /// Cuenta el total de opiniones de un local (para paginación)
        /// </summary>
        public int ContarOpinionesLocal(int idLocal)
        {
            var parametros = new List<Parametro>
            {
                new Parametro("p_id_local", idLocal)
            };

            DataTable datos = conexion.EjecutarConsulta("sp_contar_opiniones_local", parametros);

            if (datos != null && datos.Rows.Count > 0)
            {
                return Convert.ToInt32(datos.Rows[0]["Total"]);
            }

            return 0;
        }

        private Opinion MapearOpinion(DataRow row)
        {
            return new Opinion
            {
                Id = Convert.ToInt32(row["Id"]),
                IdLocal = Convert.ToInt32(row["IdLocal"]),
                IdUsuario = Convert.ToInt32(row["IdUsuario"]),
                NombreUsuario = row["NombreUsuario"]?.ToString(),
                FotoUsuario = row["FotoUsuario"]?.ToString(),
                Calificacion = Convert.ToInt32(row["Calificacion"]),
                Comentario = row["Comentario"]?.ToString(),
                FechaOpinion = Convert.ToDateTime(row["FechaOpinion"]),
                RespuestaDueno = row["RespuestaDueno"]?.ToString(),
                FechaRespuesta = row["FechaRespuesta"] != DBNull.Value
                    ? Convert.ToDateTime(row["FechaRespuesta"])
                    : null,
                Estado = Convert.ToInt32(row["Estado"]),
                CantidadRespuestas = row.Table.Columns.Contains("CantidadRespuestas")
                    ? Convert.ToInt32(row["CantidadRespuestas"])
                    : 0
            };
        }
    }
}
