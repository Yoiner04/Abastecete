using BusinessLogic.Models;
using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;

namespace BusinessLogic
{
    public class ManejadorSuscripciones
    {
        private readonly Connection conexion;

        public ManejadorSuscripciones()
        {
            conexion = new Connection();
        }

        /// <summary>
        /// Obtiene la suscripción activa de un local
        /// </summary>
        public Suscripcion ObtenerSuscripcionActiva(int idLocal)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_local", idLocal)
            };

            DataTable datos = conexion.EjecutarConsulta("obtener_suscripcion_activa", parametros);

            if (datos.Rows.Count > 0)
            {
                DataRow row = datos.Rows[0];
                return MapearSuscripcion(row);
            }

            return null;
        }

        /// <summary>
        /// Obtiene todas las suscripciones de un local (históricas y activa)
        /// </summary>
        public List<Suscripcion> ObtenerSuscripcionesLocal(int idLocal)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_local", idLocal)
            };

            DataTable datos = conexion.EjecutarConsulta("obtener_suscripciones_local", parametros);
            List<Suscripcion> suscripciones = new List<Suscripcion>();

            foreach (DataRow row in datos.Rows)
            {
                suscripciones.Add(MapearSuscripcionSimple(row));
            }

            return suscripciones;
        }

        /// <summary>
        /// Crea una nueva suscripción para un local
        /// </summary>
        public (int IdSuscripcion, string TipoCambio) CrearSuscripcion(
            int idLocal,
            int idTipoMembresia,
            string periodo,
            decimal monto,
            string metodoPago,
            string notas = null)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_local", idLocal),
                new Parametro("p_id_tipo_membresia", idTipoMembresia),
                new Parametro("p_periodo", periodo),
                new Parametro("p_monto", monto),
                new Parametro("p_metodo_pago", metodoPago),
                new Parametro("p_notas", notas ?? (object)DBNull.Value)
            };

            DataTable resultado = conexion.EjecutarConsulta("crear_suscripcion", parametros);

            if (resultado.Rows.Count > 0)
            {
                DataRow row = resultado.Rows[0];
                return (
                    Convert.ToInt32(row["IdSuscripcion"]),
                    row["TipoCambio"].ToString()
                );
            }

            return (0, null);
        }

        /// <summary>
        /// Renueva una suscripción existente extendiendo su fecha de fin
        /// </summary>
        public (int IdSuscripcion, DateTime NuevaFechaFin) RenovarSuscripcion(
            int idSuscripcion,
            string periodo,
            decimal monto,
            string metodoPago)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_suscripcion", idSuscripcion),
                new Parametro("p_periodo", periodo),
                new Parametro("p_monto", monto),
                new Parametro("p_metodo_pago", metodoPago)
            };

            DataTable resultado = conexion.EjecutarConsulta("renovar_suscripcion", parametros);

            if (resultado.Rows.Count > 0)
            {
                DataRow row = resultado.Rows[0];
                return (
                    Convert.ToInt32(row["IdSuscripcion"]),
                    Convert.ToDateTime(row["NuevaFechaFin"])
                );
            }

            return (0, DateTime.MinValue);
        }

        /// <summary>
        /// Cancela una suscripción
        /// </summary>
        public bool CancelarSuscripcion(int idSuscripcion, string motivo)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_suscripcion", idSuscripcion),
                new Parametro("p_motivo", motivo ?? "Cancelación solicitada por el usuario")
            };

            DataTable resultado = conexion.EjecutarConsulta("cancelar_suscripcion", parametros);
            return resultado.Rows.Count > 0;
        }

        /// <summary>
        /// Obtiene el historial de cambios de membresía de un local
        /// </summary>
        public List<HistorialMembresia> ObtenerHistorial(int idLocal)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_local", idLocal)
            };

            DataTable datos = conexion.EjecutarConsulta("consultar_historial_membresia", parametros);
            List<HistorialMembresia> historial = new List<HistorialMembresia>();

            foreach (DataRow row in datos.Rows)
            {
                historial.Add(MapearHistorial(row));
            }

            return historial;
        }

        /// <summary>
        /// Ejecuta la verificación de suscripciones vencidas
        /// </summary>
        public int VerificarSuscripcionesVencidas()
        {
            DataTable resultado = conexion.EjecutarConsulta("verificar_suscripciones_vencidas", new List<Parametro>());

            if (resultado.Rows.Count > 0)
            {
                return Convert.ToInt32(resultado.Rows[0]["SuscripcionesVencidas"]);
            }

            return 0;
        }

        #region Métodos de mapeo privados

        private Suscripcion MapearSuscripcion(DataRow row)
        {
            var suscripcion = new Suscripcion
            {
                Id = Convert.ToInt32(row["Id"]),
                LocalId = Convert.ToInt32(row["LocalId"]),
                Estado = Convert.ToInt32(row["Estado"]),
                FechaInicio = Convert.ToDateTime(row["FechaInicio"]),
                FechaFin = Convert.ToDateTime(row["FechaFin"]),
                FechaCreacion = Convert.ToDateTime(row["FechaCreacion"]),
                Periodo = row["Periodo"]?.ToString(),
                Notas = row["Notas"]?.ToString()
            };

            if (row["MontoPagado"] != DBNull.Value)
                suscripcion.MontoPagado = Convert.ToDecimal(row["MontoPagado"]);

            if (row["MetodoPago"] != DBNull.Value)
                suscripcion.MetodoPago = row["MetodoPago"].ToString();

            // Mapear tipo de membresía
            suscripcion.TipoMembresia = new Membresia
            {
                Id = Convert.ToInt32(row["TipoMembresiaId"]),
                Nombre = row["TipoMembresiaNombre"].ToString(),
                Descripcion = row["TipoMembresiaDescripcion"]?.ToString(),
                Costo = row["TipoMembresiaCostoMes"] != DBNull.Value
                    ? float.Parse(row["TipoMembresiaCostoMes"].ToString())
                    : 0,
                Costo_trimestral = row["TipoMembresiaCostoTrimestre"] != DBNull.Value
                    ? float.Parse(row["TipoMembresiaCostoTrimestre"].ToString())
                    : 0,
                Costo_semestral = row["TipoMembresiaCostoSemestre"] != DBNull.Value
                    ? float.Parse(row["TipoMembresiaCostoSemestre"].ToString())
                    : 0,
                Costo_anual = row["TipoMembresiaCostoAnio"] != DBNull.Value
                    ? float.Parse(row["TipoMembresiaCostoAnio"].ToString())
                    : 0,
                Estado = row["TipoMembresiaEstado"] != DBNull.Value
                    ? Convert.ToInt32(row["TipoMembresiaEstado"])
                    : 1
            };

            return suscripcion;
        }

        private Suscripcion MapearSuscripcionSimple(DataRow row)
        {
            var suscripcion = new Suscripcion
            {
                Id = Convert.ToInt32(row["Id"]),
                LocalId = Convert.ToInt32(row["LocalId"]),
                Estado = Convert.ToInt32(row["Estado"]),
                FechaInicio = Convert.ToDateTime(row["FechaInicio"]),
                FechaFin = Convert.ToDateTime(row["FechaFin"]),
                FechaCreacion = Convert.ToDateTime(row["FechaCreacion"]),
                Periodo = row["Periodo"]?.ToString(),
                Notas = row["Notas"]?.ToString()
            };

            if (row["MontoPagado"] != DBNull.Value)
                suscripcion.MontoPagado = Convert.ToDecimal(row["MontoPagado"]);

            if (row["MetodoPago"] != DBNull.Value)
                suscripcion.MetodoPago = row["MetodoPago"].ToString();

            suscripcion.TipoMembresia = new Membresia
            {
                Id = Convert.ToInt32(row["TipoMembresiaId"]),
                Nombre = row["TipoMembresiaNombre"].ToString(),
                Costo = row["TipoMembresiaCostoMes"] != DBNull.Value
                    ? float.Parse(row["TipoMembresiaCostoMes"].ToString())
                    : 0
            };

            return suscripcion;
        }

        private HistorialMembresia MapearHistorial(DataRow row)
        {
            var historial = new HistorialMembresia
            {
                Id = Convert.ToInt32(row["Id"]),
                LocalId = Convert.ToInt32(row["LocalId"]),
                TipoCambio = row["TipoCambio"].ToString(),
                FechaCambio = Convert.ToDateTime(row["FechaCambio"]),
                FechaInicioPeriodo = Convert.ToDateTime(row["FechaInicioPeriodo"]),
                FechaFinPeriodo = Convert.ToDateTime(row["FechaFinPeriodo"]),
                Notas = row["Notas"]?.ToString()
            };

            if (row["SuscripcionId"] != DBNull.Value)
                historial.SuscripcionId = Convert.ToInt32(row["SuscripcionId"]);

            if (row["Monto"] != DBNull.Value)
                historial.Monto = Convert.ToDecimal(row["Monto"]);

            if (row["Periodo"] != DBNull.Value)
                historial.Periodo = row["Periodo"].ToString();

            // Tipo anterior (puede ser null)
            if (row["TipoAnteriorId"] != DBNull.Value)
            {
                historial.TipoAnterior = new Membresia
                {
                    Id = Convert.ToInt32(row["TipoAnteriorId"]),
                    Nombre = row["TipoAnteriorNombre"]?.ToString()
                };
            }

            // Tipo nuevo
            historial.TipoNuevo = new Membresia
            {
                Id = Convert.ToInt32(row["TipoNuevoId"]),
                Nombre = row["TipoNuevoNombre"].ToString()
            };

            return historial;
        }

        #endregion
    }
}
