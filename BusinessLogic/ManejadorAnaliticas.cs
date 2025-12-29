using BusinessLogic.Models;
using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;

namespace BusinessLogic
{
    public class ManejadorAnaliticas
    {
        private Connection conexion = new Connection();

        /// <summary>
        /// Registra un evento de analítica
        /// </summary>
        public bool RegistrarEvento(int idLocal, TipoEventoAnalitica tipoEvento, int? idProducto = null,
            string? ipVisitante = null, string? userAgent = null, string? referrer = null)
        {
            try
            {
                List<Parametro> parametros = new List<Parametro>
                {
                    new Parametro("p_id_local", idLocal),
                    new Parametro("p_id_producto", idProducto ?? (object)DBNull.Value),
                    new Parametro("p_tipo_evento", tipoEvento.ToString()),
                    new Parametro("p_ip_visitante", ipVisitante ?? (object)DBNull.Value),
                    new Parametro("p_user_agent", userAgent?.Length > 500 ? userAgent.Substring(0, 500) : userAgent ?? (object)DBNull.Value),
                    new Parametro("p_referrer", referrer?.Length > 500 ? referrer.Substring(0, 500) : referrer ?? (object)DBNull.Value)
                };

                return conexion.EjecutarTransaccion("registrar_evento_analitica", parametros);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al registrar evento: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// Obtiene las estadísticas totales de un local en un rango de fechas
        /// </summary>
        public EstadisticasLocal ObtenerEstadisticas(int idLocal, DateTime fechaInicio, DateTime fechaFin)
        {
            var estadisticas = new EstadisticasLocal();

            try
            {
                List<Parametro> parametros = new List<Parametro>
                {
                    new Parametro("p_id_local", idLocal),
                    new Parametro("p_fecha_inicio", fechaInicio.Date),
                    new Parametro("p_fecha_fin", fechaFin.Date)
                };

                DataTable data = conexion.EjecutarConsulta("obtener_estadisticas_local", parametros);

                if (data.Rows.Count > 0)
                {
                    DataRow row = data.Rows[0];
                    estadisticas.TotalVisitas = Convert.ToInt32(row["total_visitas"]);
                    estadisticas.TotalVisitasProductos = Convert.ToInt32(row["total_visitas_productos"]);
                    estadisticas.TotalClicsWhatsapp = Convert.ToInt32(row["total_clics_whatsapp"]);
                    estadisticas.TotalClicsTelefono = Convert.ToInt32(row["total_clics_telefono"]);
                    estadisticas.TotalAparicionesBusqueda = Convert.ToInt32(row["total_apariciones_busqueda"]);
                    estadisticas.TotalCompartidos = Convert.ToInt32(row["total_compartidos"]);
                }

                // Obtener comparativa con período anterior
                var comparativa = ObtenerComparativa(idLocal, fechaInicio, fechaFin);
                if (comparativa != null)
                {
                    estadisticas.CambioVisitas = comparativa.CambioVisitas;
                    estadisticas.CambioClicsWhatsapp = comparativa.CambioClicsWhatsapp;
                    estadisticas.CambioVisitasProductos = comparativa.CambioVisitasProductos;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al obtener estadísticas: {ex.Message}");
            }

            return estadisticas;
        }

        /// <summary>
        /// Obtiene datos diarios para gráficos
        /// </summary>
        public List<EstadisticaDiaria> ObtenerEstadisticasDiarias(int idLocal, DateTime fechaInicio, DateTime fechaFin)
        {
            var lista = new List<EstadisticaDiaria>();

            try
            {
                List<Parametro> parametros = new List<Parametro>
                {
                    new Parametro("p_id_local", idLocal),
                    new Parametro("p_fecha_inicio", fechaInicio.Date),
                    new Parametro("p_fecha_fin", fechaFin.Date)
                };

                DataTable data = conexion.EjecutarConsulta("obtener_estadisticas_diarias_local", parametros);

                // Crear diccionario con los datos existentes
                var datosExistentes = new Dictionary<DateTime, EstadisticaDiaria>();
                foreach (DataRow row in data.Rows)
                {
                    var fecha = Convert.ToDateTime(row["fecha"]);
                    datosExistentes[fecha.Date] = new EstadisticaDiaria
                    {
                        Fecha = fecha,
                        Visitas = Convert.ToInt32(row["visitas"]),
                        VisitasProductos = Convert.ToInt32(row["visitas_productos"]),
                        ClicsWhatsapp = Convert.ToInt32(row["clics_whatsapp"]),
                        ClicsTelefono = Convert.ToInt32(row["clics_telefono"]),
                        AparicionesBusqueda = Convert.ToInt32(row["apariciones_busqueda"]),
                        Compartidos = Convert.ToInt32(row["compartidos"])
                    };
                }

                // Rellenar días sin datos con ceros
                for (var fecha = fechaInicio.Date; fecha <= fechaFin.Date; fecha = fecha.AddDays(1))
                {
                    if (datosExistentes.ContainsKey(fecha))
                    {
                        lista.Add(datosExistentes[fecha]);
                    }
                    else
                    {
                        lista.Add(new EstadisticaDiaria { Fecha = fecha });
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al obtener estadísticas diarias: {ex.Message}");
            }

            return lista;
        }

        /// <summary>
        /// Obtiene los productos más vistos de un local
        /// </summary>
        public List<ProductoMasVisto> ObtenerProductosMasVistos(int idLocal, DateTime fechaInicio, DateTime fechaFin, int limite = 5)
        {
            var lista = new List<ProductoMasVisto>();

            try
            {
                List<Parametro> parametros = new List<Parametro>
                {
                    new Parametro("p_id_local", idLocal),
                    new Parametro("p_fecha_inicio", fechaInicio.Date),
                    new Parametro("p_fecha_fin", fechaFin.Date),
                    new Parametro("p_limite", limite)
                };

                DataTable data = conexion.EjecutarConsulta("obtener_productos_mas_vistos", parametros);

                foreach (DataRow row in data.Rows)
                {
                    lista.Add(new ProductoMasVisto
                    {
                        IdProducto = Convert.ToInt32(row["id_producto"]),
                        NombreProducto = row["nombre_producto"]?.ToString() ?? "",
                        ImagenUrl = row["imagen_url"]?.ToString(),
                        TotalVistas = Convert.ToInt32(row["total_vistas"])
                    });
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al obtener productos más vistos: {ex.Message}");
            }

            return lista;
        }

        /// <summary>
        /// Obtiene comparativa con el período anterior
        /// </summary>
        private EstadisticasLocal? ObtenerComparativa(int idLocal, DateTime fechaInicio, DateTime fechaFin)
        {
            try
            {
                List<Parametro> parametros = new List<Parametro>
                {
                    new Parametro("p_id_local", idLocal),
                    new Parametro("p_fecha_inicio", fechaInicio.Date),
                    new Parametro("p_fecha_fin", fechaFin.Date)
                };

                DataTable data = conexion.EjecutarConsulta("obtener_comparativa_periodo", parametros);

                int visitasActual = 0, visitasAnterior = 0;
                int whatsappActual = 0, whatsappAnterior = 0;
                int productosActual = 0, productosAnterior = 0;

                foreach (DataRow row in data.Rows)
                {
                    string periodo = row["periodo"]?.ToString() ?? "";
                    if (periodo == "actual")
                    {
                        visitasActual = Convert.ToInt32(row["visitas"]);
                        whatsappActual = Convert.ToInt32(row["clics_whatsapp"]);
                        productosActual = Convert.ToInt32(row["visitas_productos"]);
                    }
                    else
                    {
                        visitasAnterior = Convert.ToInt32(row["visitas"]);
                        whatsappAnterior = Convert.ToInt32(row["clics_whatsapp"]);
                        productosAnterior = Convert.ToInt32(row["visitas_productos"]);
                    }
                }

                return new EstadisticasLocal
                {
                    CambioVisitas = CalcularPorcentajeCambio(visitasAnterior, visitasActual),
                    CambioClicsWhatsapp = CalcularPorcentajeCambio(whatsappAnterior, whatsappActual),
                    CambioVisitasProductos = CalcularPorcentajeCambio(productosAnterior, productosActual)
                };
            }
            catch
            {
                return null;
            }
        }

        private double? CalcularPorcentajeCambio(int anterior, int actual)
        {
            if (anterior == 0)
            {
                return actual > 0 ? 100 : 0;
            }
            return Math.Round(((double)(actual - anterior) / anterior) * 100, 1);
        }

        /// <summary>
        /// Obtiene el dashboard completo de analíticas
        /// </summary>
        public DashboardAnaliticas ObtenerDashboard(int idLocal, DateTime fechaInicio, DateTime fechaFin)
        {
            return new DashboardAnaliticas
            {
                FechaInicio = fechaInicio,
                FechaFin = fechaFin,
                Estadisticas = ObtenerEstadisticas(idLocal, fechaInicio, fechaFin),
                DatosGrafico = ObtenerEstadisticasDiarias(idLocal, fechaInicio, fechaFin),
                ProductosMasVistos = ObtenerProductosMasVistos(idLocal, fechaInicio, fechaFin)
            };
        }

        // ==================== Métodos para Dashboard Admin ====================

        /// <summary>
        /// Obtiene las estadísticas globales del sistema
        /// </summary>
        public EstadisticasGlobales ObtenerEstadisticasGlobales(DateTime fechaInicio, DateTime fechaFin)
        {
            var estadisticas = new EstadisticasGlobales();

            try
            {
                List<Parametro> parametros = new List<Parametro>
                {
                    new Parametro("p_fecha_inicio", fechaInicio.Date),
                    new Parametro("p_fecha_fin", fechaFin.Date)
                };

                DataTable data = conexion.EjecutarConsulta("sp_obtener_estadisticas_globales", parametros);

                if (data.Rows.Count > 0)
                {
                    DataRow row = data.Rows[0];
                    estadisticas.TotalLocalesActivos = row["TotalLocalesActivos"] != DBNull.Value ? Convert.ToInt32(row["TotalLocalesActivos"]) : 0;
                    estadisticas.TotalLocales = row["TotalLocales"] != DBNull.Value ? Convert.ToInt32(row["TotalLocales"]) : 0;
                    estadisticas.TotalUsuariosActivos = row["TotalUsuariosActivos"] != DBNull.Value ? Convert.ToInt32(row["TotalUsuariosActivos"]) : 0;
                    estadisticas.TotalUsuarios = row["TotalUsuarios"] != DBNull.Value ? Convert.ToInt32(row["TotalUsuarios"]) : 0;
                    estadisticas.NuevosUsuariosPeriodo = row["NuevosUsuariosPeriodo"] != DBNull.Value ? Convert.ToInt32(row["NuevosUsuariosPeriodo"]) : 0;
                    estadisticas.NuevosLocalesPeriodo = row["NuevosLocalesPeriodo"] != DBNull.Value ? Convert.ToInt32(row["NuevosLocalesPeriodo"]) : 0;
                    estadisticas.TotalProductosActivos = row["TotalProductosActivos"] != DBNull.Value ? Convert.ToInt32(row["TotalProductosActivos"]) : 0;
                    estadisticas.TotalVisitasLocales = row["TotalVisitasLocales"] != DBNull.Value ? Convert.ToInt32(row["TotalVisitasLocales"]) : 0;
                    estadisticas.TotalClicsWhatsapp = row["TotalClicsWhatsapp"] != DBNull.Value ? Convert.ToInt32(row["TotalClicsWhatsapp"]) : 0;
                    estadisticas.TotalVisitasProductos = row["TotalVisitasProductos"] != DBNull.Value ? Convert.ToInt32(row["TotalVisitasProductos"]) : 0;
                    estadisticas.TotalBusquedas = row["TotalBusquedas"] != DBNull.Value ? Convert.ToInt32(row["TotalBusquedas"]) : 0;
                }

                // Obtener comparativa con período anterior
                var comparativa = ObtenerComparativaGlobal(fechaInicio, fechaFin);
                if (comparativa != null)
                {
                    estadisticas.CambioVisitas = comparativa.CambioVisitas;
                    estadisticas.CambioWhatsapp = comparativa.CambioWhatsapp;
                    estadisticas.CambioNuevosUsuarios = comparativa.CambioNuevosUsuarios;
                    estadisticas.CambioNuevosLocales = comparativa.CambioNuevosLocales;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al obtener estadísticas globales: {ex.Message}");
            }

            return estadisticas;
        }

        /// <summary>
        /// Obtiene la distribución de membresías
        /// </summary>
        public List<DistribucionMembresia> ObtenerDistribucionMembresias()
        {
            var lista = new List<DistribucionMembresia>();

            try
            {
                DataTable data = conexion.EjecutarConsulta("sp_obtener_distribucion_membresias", new List<Parametro>());

                foreach (DataRow row in data.Rows)
                {
                    lista.Add(new DistribucionMembresia
                    {
                        IdMembresia = Convert.ToInt32(row["IdMembresia"]),
                        NombreMembresia = row["NombreMembresia"]?.ToString() ?? "",
                        CantidadSuscripciones = row["CantidadSuscripciones"] != DBNull.Value ? Convert.ToInt32(row["CantidadSuscripciones"]) : 0,
                        Activas = row["Activas"] != DBNull.Value ? Convert.ToInt32(row["Activas"]) : 0,
                        Pendientes = row["Pendientes"] != DBNull.Value ? Convert.ToInt32(row["Pendientes"]) : 0,
                        Vencidas = row["Vencidas"] != DBNull.Value ? Convert.ToInt32(row["Vencidas"]) : 0
                    });
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al obtener distribución de membresías: {ex.Message}");
            }

            return lista;
        }

        /// <summary>
        /// Obtiene los locales más visitados
        /// </summary>
        public List<LocalMasVisitado> ObtenerLocalesMasVisitados(DateTime fechaInicio, DateTime fechaFin, int limite = 10)
        {
            var lista = new List<LocalMasVisitado>();

            try
            {
                List<Parametro> parametros = new List<Parametro>
                {
                    new Parametro("p_fecha_inicio", fechaInicio.Date),
                    new Parametro("p_fecha_fin", fechaFin.Date),
                    new Parametro("p_limite", limite)
                };

                DataTable data = conexion.EjecutarConsulta("sp_obtener_locales_mas_visitados", parametros);

                foreach (DataRow row in data.Rows)
                {
                    lista.Add(new LocalMasVisitado
                    {
                        IdLocal = Convert.ToInt32(row["IdLocal"]),
                        NombreLocal = row["NombreLocal"]?.ToString() ?? "",
                        LogoUrl = row["LogoUrl"]?.ToString(),
                        Direccion = row["Direccion"]?.ToString() ?? "",
                        TotalVisitas = row["TotalVisitas"] != DBNull.Value ? Convert.ToInt32(row["TotalVisitas"]) : 0
                    });
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al obtener locales más visitados: {ex.Message}");
            }

            return lista;
        }

        /// <summary>
        /// Obtiene estadísticas diarias globales para gráficos
        /// </summary>
        public List<EstadisticaDiariaGlobal> ObtenerEstadisticasDiariasGlobales(DateTime fechaInicio, DateTime fechaFin)
        {
            var lista = new List<EstadisticaDiariaGlobal>();

            try
            {
                List<Parametro> parametros = new List<Parametro>
                {
                    new Parametro("p_fecha_inicio", fechaInicio.Date),
                    new Parametro("p_fecha_fin", fechaFin.Date)
                };

                DataTable data = conexion.EjecutarConsulta("sp_obtener_estadisticas_diarias_globales", parametros);

                foreach (DataRow row in data.Rows)
                {
                    lista.Add(new EstadisticaDiariaGlobal
                    {
                        Fecha = Convert.ToDateTime(row["Fecha"]),
                        Visitas = row["Visitas"] != DBNull.Value ? Convert.ToInt32(row["Visitas"]) : 0,
                        ClicsWhatsapp = row["ClicsWhatsapp"] != DBNull.Value ? Convert.ToInt32(row["ClicsWhatsapp"]) : 0,
                        VisitasProductos = row["VisitasProductos"] != DBNull.Value ? Convert.ToInt32(row["VisitasProductos"]) : 0,
                        NuevosUsuarios = row["NuevosUsuarios"] != DBNull.Value ? Convert.ToInt32(row["NuevosUsuarios"]) : 0,
                        NuevosLocales = row["NuevosLocales"] != DBNull.Value ? Convert.ToInt32(row["NuevosLocales"]) : 0
                    });
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al obtener estadísticas diarias globales: {ex.Message}");
            }

            return lista;
        }

        /// <summary>
        /// Obtiene actividad reciente del sistema
        /// </summary>
        public List<ActividadReciente> ObtenerActividadReciente(int limite = 20)
        {
            var lista = new List<ActividadReciente>();

            try
            {
                List<Parametro> parametros = new List<Parametro>
                {
                    new Parametro("p_limite", limite)
                };

                DataTable data = conexion.EjecutarConsulta("sp_obtener_actividad_reciente", parametros);

                foreach (DataRow row in data.Rows)
                {
                    lista.Add(new ActividadReciente
                    {
                        IdEvento = Convert.ToInt64(row["IdEvento"]),
                        TipoEvento = row["TipoEvento"]?.ToString() ?? "",
                        FechaHora = Convert.ToDateTime(row["FechaHora"]),
                        NombreLocal = row["NombreLocal"]?.ToString() ?? "",
                        IdLocal = Convert.ToInt32(row["IdLocal"]),
                        NombreProducto = row["NombreProducto"]?.ToString(),
                        IdProducto = row["IdProducto"] != DBNull.Value ? Convert.ToInt32(row["IdProducto"]) : (int?)null
                    });
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al obtener actividad reciente: {ex.Message}");
            }

            return lista;
        }

        /// <summary>
        /// Obtiene comparativa global con período anterior
        /// </summary>
        private EstadisticasGlobales? ObtenerComparativaGlobal(DateTime fechaInicio, DateTime fechaFin)
        {
            try
            {
                var diasPeriodo = (fechaFin - fechaInicio).Days + 1;
                var fechaInicioAnterior = fechaInicio.AddDays(-diasPeriodo);
                var fechaFinAnterior = fechaInicio.AddDays(-1);

                List<Parametro> parametros = new List<Parametro>
                {
                    new Parametro("p_fecha_inicio_actual", fechaInicio.Date),
                    new Parametro("p_fecha_fin_actual", fechaFin.Date),
                    new Parametro("p_fecha_inicio_anterior", fechaInicioAnterior.Date),
                    new Parametro("p_fecha_fin_anterior", fechaFinAnterior.Date)
                };

                DataTable data = conexion.EjecutarConsulta("sp_comparar_estadisticas_globales", parametros);

                if (data.Rows.Count > 0)
                {
                    DataRow row = data.Rows[0];
                    int visitasActual = row["VisitasActual"] != DBNull.Value ? Convert.ToInt32(row["VisitasActual"]) : 0;
                    int visitasAnterior = row["VisitasAnterior"] != DBNull.Value ? Convert.ToInt32(row["VisitasAnterior"]) : 0;
                    int whatsappActual = row["WhatsappActual"] != DBNull.Value ? Convert.ToInt32(row["WhatsappActual"]) : 0;
                    int whatsappAnterior = row["WhatsappAnterior"] != DBNull.Value ? Convert.ToInt32(row["WhatsappAnterior"]) : 0;
                    int usuariosActual = row["NuevosUsuariosActual"] != DBNull.Value ? Convert.ToInt32(row["NuevosUsuariosActual"]) : 0;
                    int usuariosAnterior = row["NuevosUsuariosAnterior"] != DBNull.Value ? Convert.ToInt32(row["NuevosUsuariosAnterior"]) : 0;
                    int localesActual = row["NuevosLocalesActual"] != DBNull.Value ? Convert.ToInt32(row["NuevosLocalesActual"]) : 0;
                    int localesAnterior = row["NuevosLocalesAnterior"] != DBNull.Value ? Convert.ToInt32(row["NuevosLocalesAnterior"]) : 0;

                    return new EstadisticasGlobales
                    {
                        CambioVisitas = CalcularPorcentajeCambio(visitasAnterior, visitasActual),
                        CambioWhatsapp = CalcularPorcentajeCambio(whatsappAnterior, whatsappActual),
                        CambioNuevosUsuarios = CalcularPorcentajeCambio(usuariosAnterior, usuariosActual),
                        CambioNuevosLocales = CalcularPorcentajeCambio(localesAnterior, localesActual)
                    };
                }
            }
            catch
            {
                // Ignorar errores de comparativa
            }

            return null;
        }

        /// <summary>
        /// Obtiene el dashboard completo de admin
        /// </summary>
        public DashboardAdmin ObtenerDashboardAdmin(DateTime fechaInicio, DateTime fechaFin)
        {
            return new DashboardAdmin
            {
                FechaInicio = fechaInicio,
                FechaFin = fechaFin,
                Estadisticas = ObtenerEstadisticasGlobales(fechaInicio, fechaFin),
                DistribucionMembresias = ObtenerDistribucionMembresias(),
                LocalesMasVisitados = ObtenerLocalesMasVisitados(fechaInicio, fechaFin),
                DatosGrafico = ObtenerEstadisticasDiariasGlobales(fechaInicio, fechaFin),
                ActividadReciente = ObtenerActividadReciente()
            };
        }
    }
}
