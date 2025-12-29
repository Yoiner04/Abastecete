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
        public Suscripcion? ObtenerSuscripcionActiva(int idLocal)
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
            string? notas = null)
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
                    row["TipoCambio"]?.ToString() ?? ""
                );
            }

            return (0, "");
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

        /// <summary>
        /// Obtiene los límites de membresía y uso actual de un local
        /// </summary>
        public LimitesMembresia ObtenerLimitesMembresia(int idLocal)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_local", idLocal)
            };

            DataTable datos = conexion.EjecutarConsulta("obtener_limites_membresia", parametros);

            if (datos.Rows.Count > 0)
            {
                DataRow row = datos.Rows[0];
                return new LimitesMembresia
                {
                    TieneSuscripcionActiva = Convert.ToInt32(row["TieneSuscripcionActiva"]) == 1,
                    DiasRestantes = Convert.ToInt32(row["DiasRestantes"]),
                    FechaVencimiento = row["FechaVencimiento"] != DBNull.Value
                        ? Convert.ToDateTime(row["FechaVencimiento"])
                        : (DateTime?)null,
                    NombreMembresia = row["NombreMembresia"]?.ToString(),
                    LimiteProductos = Convert.ToInt32(row["LimiteProductos"]),
                    LimiteOfertasSimultaneas = Convert.ToInt32(row["LimiteOfertasSimultaneas"]),
                    LimiteOfertasTotal = Convert.ToInt32(row["LimiteOfertasTotal"]),
                    DuracionOfertaHoras = Convert.ToInt32(row["DuracionOfertaHoras"]),
                    ProductosActuales = Convert.ToInt32(row["ProductosActuales"]),
                    OfertasActivas = Convert.ToInt32(row["OfertasActivas"]),
                    OfertasUsadasPeriodo = Convert.ToInt32(row["OfertasUsadasPeriodo"]),
                    PuedeAgregarProductos = Convert.ToInt32(row["PuedeAgregarProductos"]) == 1,
                    PuedeCrearOferta = Convert.ToInt32(row["PuedeCrearOferta"]) == 1
                };
            }

            // Si no hay datos, retornar un objeto vacío indicando que no tiene membresía
            return new LimitesMembresia
            {
                TieneSuscripcionActiva = false,
                DiasRestantes = 0,
                NombreMembresia = null,
                PuedeAgregarProductos = false,
                PuedeCrearOferta = false
            };
        }

        /// <summary>
        /// Valida si un local puede agregar más productos según su membresía
        /// </summary>
        public ValidacionProducto ValidarLimiteProductos(int idLocal)
        {
            var limites = ObtenerLimitesMembresia(idLocal);

            if (!limites.TieneSuscripcionActiva)
            {
                return new ValidacionProducto
                {
                    PuedeAgregar = false,
                    ProductosActuales = limites.ProductosActuales,
                    LimiteMaximo = 0,
                    Mensaje = "No tienes una membresía activa. Activa o renueva tu plan para agregar productos."
                };
            }

            if (limites.ProductosIlimitados)
            {
                return new ValidacionProducto
                {
                    PuedeAgregar = true,
                    ProductosActuales = limites.ProductosActuales,
                    LimiteMaximo = 0,
                    Mensaje = "Sin límite de productos"
                };
            }

            if (limites.ProductosActuales >= limites.LimiteProductos)
            {
                return new ValidacionProducto
                {
                    PuedeAgregar = false,
                    ProductosActuales = limites.ProductosActuales,
                    LimiteMaximo = limites.LimiteProductos,
                    Mensaje = $"Has alcanzado el límite de {limites.LimiteProductos} productos de tu plan. Mejora tu membresía para agregar más."
                };
            }

            return new ValidacionProducto
            {
                PuedeAgregar = true,
                ProductosActuales = limites.ProductosActuales,
                LimiteMaximo = limites.LimiteProductos,
                Mensaje = $"Puedes agregar productos. Usados: {limites.ProductosActuales}/{limites.LimiteProductos}"
            };
        }

        /// <summary>
        /// Valida si un local puede crear más ofertas flash según su membresía
        /// </summary>
        public ValidacionOferta ValidarLimiteOfertas(int idLocal)
        {
            var limites = ObtenerLimitesMembresia(idLocal);

            if (!limites.TieneSuscripcionActiva)
            {
                return new ValidacionOferta
                {
                    PuedeCrear = false,
                    Mensaje = "No tienes una membresía activa. Activa o renueva tu plan para crear ofertas.",
                    DuracionHoras = 24
                };
            }

            // Verificar límite de simultáneas
            if (limites.OfertasActivas >= limites.LimiteOfertasSimultaneas)
            {
                return new ValidacionOferta
                {
                    PuedeCrear = false,
                    Mensaje = $"Ya tienes {limites.OfertasActivas} ofertas activas. Tu plan permite máximo {limites.LimiteOfertasSimultaneas}.",
                    OfertasActivas = limites.OfertasActivas,
                    LimiteSimultaneas = limites.LimiteOfertasSimultaneas,
                    OfertasUsadas = limites.OfertasUsadasPeriodo,
                    LimiteTotal = limites.LimiteOfertasTotal,
                    DuracionHoras = limites.DuracionOfertaHoras
                };
            }

            // Verificar límite total (si aplica)
            if (limites.LimiteOfertasTotal > 0 && limites.OfertasUsadasPeriodo >= limites.LimiteOfertasTotal)
            {
                return new ValidacionOferta
                {
                    PuedeCrear = false,
                    Mensaje = $"Has usado {limites.OfertasUsadasPeriodo} de {limites.LimiteOfertasTotal} ofertas permitidas en tu suscripción.",
                    OfertasActivas = limites.OfertasActivas,
                    LimiteSimultaneas = limites.LimiteOfertasSimultaneas,
                    OfertasUsadas = limites.OfertasUsadasPeriodo,
                    LimiteTotal = limites.LimiteOfertasTotal,
                    DuracionHoras = limites.DuracionOfertaHoras
                };
            }

            return new ValidacionOferta
            {
                PuedeCrear = true,
                Mensaje = "Puedes crear ofertas.",
                OfertasActivas = limites.OfertasActivas,
                LimiteSimultaneas = limites.LimiteOfertasSimultaneas,
                OfertasUsadas = limites.OfertasUsadasPeriodo,
                LimiteTotal = limites.LimiteOfertasTotal,
                DuracionHoras = limites.DuracionOfertaHoras
            };
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
                suscripcion.MetodoPago = row["MetodoPago"]?.ToString();

            // Mapear tipo de membresía
            suscripcion.TipoMembresia = new Membresia
            {
                Id = Convert.ToInt32(row["TipoMembresiaId"]),
                Nombre = row["TipoMembresiaNombre"]?.ToString() ?? "",
                Costo = row["TipoMembresiaCostoMes"] != DBNull.Value
                    ? float.Parse(row["TipoMembresiaCostoMes"]?.ToString() ?? "0")
                    : 0,
                Costo_trimestral = row["TipoMembresiaCostoTrimestre"] != DBNull.Value
                    ? float.Parse(row["TipoMembresiaCostoTrimestre"]?.ToString() ?? "0")
                    : 0,
                Costo_semestral = row["TipoMembresiaCostoSemestre"] != DBNull.Value
                    ? float.Parse(row["TipoMembresiaCostoSemestre"]?.ToString() ?? "0")
                    : 0,
                Costo_anual = row["TipoMembresiaCostoAnio"] != DBNull.Value
                    ? float.Parse(row["TipoMembresiaCostoAnio"]?.ToString() ?? "0")
                    : 0,
                Estado = row["TipoMembresiaEstado"] != DBNull.Value
                    ? Convert.ToInt32(row["TipoMembresiaEstado"])
                    : 1,
                Duracion = row.Table.Columns.Contains("TipoMembresiaDuracion") && row["TipoMembresiaDuracion"] != DBNull.Value
                    ? Convert.ToInt32(row["TipoMembresiaDuracion"])
                    : 0,
                Cantidad = row.Table.Columns.Contains("TipoMembresiaCantidad") && row["TipoMembresiaCantidad"] != DBNull.Value
                    ? Convert.ToInt32(row["TipoMembresiaCantidad"])
                    : 0,
                OfertasFlashSimultaneas = row.Table.Columns.Contains("TipoMembresiaOfertasSimultaneas") && row["TipoMembresiaOfertasSimultaneas"] != DBNull.Value
                    ? Convert.ToInt32(row["TipoMembresiaOfertasSimultaneas"])
                    : 1,
                OfertasFlashTotal = row.Table.Columns.Contains("TipoMembresiaOfertasTotal") && row["TipoMembresiaOfertasTotal"] != DBNull.Value
                    ? Convert.ToInt32(row["TipoMembresiaOfertasTotal"])
                    : 0
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
                suscripcion.MetodoPago = row["MetodoPago"]?.ToString();

            suscripcion.TipoMembresia = new Membresia
            {
                Id = Convert.ToInt32(row["TipoMembresiaId"]),
                Nombre = row["TipoMembresiaNombre"]?.ToString() ?? "",
                Costo = row["TipoMembresiaCostoMes"] != DBNull.Value
                    ? float.Parse(row["TipoMembresiaCostoMes"]?.ToString() ?? "0")
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
                TipoCambio = row["TipoCambio"]?.ToString() ?? "",
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
                historial.Periodo = row["Periodo"]?.ToString();

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
                Nombre = row["TipoNuevoNombre"]?.ToString() ?? ""
            };

            return historial;
        }

        #endregion
    }
}
