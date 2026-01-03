using BusinessLogic.Models;
using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;

namespace BusinessLogic
{
    public class ManejadorAddons : Interfaces.IManejadorAddons
    {
        private Connection conexion = new Connection();

        /// <summary>
        /// Obtiene todos los addons disponibles para comprar
        /// </summary>
        public List<AddonTipo> ObtenerAddonsDisponibles()
        {
            DataTable data = conexion.EjecutarConsulta("obtener_addons_disponibles");
            return MapearAddonsTipo(data);
        }

        /// <summary>
        /// Obtiene los addons comprados por un local
        /// </summary>
        public List<AddonLocal> ObtenerAddonsLocal(int idLocal)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id_local", idLocal)
            };
            DataTable data = conexion.EjecutarConsulta("obtener_addons_local", parametros);
            return MapearAddonsLocal(data);
        }

        /// <summary>
        /// Registra la compra de un addon
        /// </summary>
        public int RegistrarCompraAddon(int idLocal, int idAddon, int cantidad, string refPago, DateTime? fechaExpiracion = null)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id_local", idLocal),
                new Parametro("p_id_addon", idAddon),
                new Parametro("p_cantidad", cantidad),
                new Parametro("p_ref_pago", refPago),
                new Parametro("p_fecha_expiracion", fechaExpiracion.HasValue ? (object)fechaExpiracion.Value : DBNull.Value)
            };
            DataTable data = conexion.EjecutarConsulta("registrar_compra_addon", parametros);

            if (data.Rows.Count > 0)
            {
                return Convert.ToInt32(data.Rows[0]["id_compra"]);
            }
            return 0;
        }

        /// <summary>
        /// Obtiene el límite efectivo de productos para un local
        /// </summary>
        public LimiteLocal ObtenerLimiteProductos(int idLocal)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id_local", idLocal)
            };
            DataTable data = conexion.EjecutarConsulta("obtener_limite_productos_local", parametros);

            if (data.Rows.Count > 0)
            {
                DataRow row = data.Rows[0];
                return new LimiteLocal()
                {
                    LimiteBase = Convert.ToInt32(row["limite_base"]),
                    AddonsExtra = Convert.ToInt32(row["addons_extra"]),
                    LimiteTotal = Convert.ToInt32(row["limite_total"]),
                    EsIlimitado = Convert.ToInt32(row["es_ilimitado"]) == 1
                };
            }

            return new LimiteLocal() { LimiteBase = 0, EsIlimitado = true };
        }

        /// <summary>
        /// Obtiene el límite efectivo de ofertas flash para un local
        /// </summary>
        public LimiteOfertasLocal ObtenerLimiteOfertas(int idLocal)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id_local", idLocal)
            };
            DataTable data = conexion.EjecutarConsulta("obtener_limite_ofertas_local", parametros);

            if (data.Rows.Count > 0)
            {
                DataRow row = data.Rows[0];
                return new LimiteOfertasLocal()
                {
                    LimiteSimultaneas = Convert.ToInt32(row["limite_simultaneas"]),
                    LimiteTotalBase = Convert.ToInt32(row["limite_total_base"]),
                    AddonsOfertas = Convert.ToInt32(row["addons_ofertas"]),
                    LimiteTotalEfectivo = Convert.ToInt32(row["limite_total_efectivo"]),
                    DuracionHoras = Convert.ToInt32(row["duracion_horas"]),
                    EsIlimitado = Convert.ToInt32(row["es_ilimitado"]) == 1
                };
            }

            return new LimiteOfertasLocal()
            {
                LimiteSimultaneas = 1,
                DuracionHoras = 6,
                EsIlimitado = false
            };
        }

        /// <summary>
        /// Obtiene addons agrupados por tipo de límite
        /// </summary>
        public Dictionary<string, List<AddonTipo>> ObtenerAddonsAgrupados()
        {
            var addons = ObtenerAddonsDisponibles();
            return addons.GroupBy(a => a.TipoLimite)
                        .ToDictionary(g => g.Key, g => g.ToList());
        }

        /// <summary>
        /// Calcula el total de addons extra por tipo para un local
        /// </summary>
        public Dictionary<string, int> ObtenerTotalesAddonsPorTipo(int idLocal)
        {
            var addons = ObtenerAddonsLocal(idLocal);
            return addons.GroupBy(a => a.TipoLimite)
                        .ToDictionary(g => g.Key, g => g.Sum(a => a.TotalAgregado));
        }

        #region Métodos de Mapeo

        private List<AddonTipo> MapearAddonsTipo(DataTable data)
        {
            List<AddonTipo> addons = new List<AddonTipo>();
            foreach (DataRow row in data.AsEnumerable())
            {
                addons.Add(new AddonTipo()
                {
                    Id = Convert.ToInt32(row["PK_ID_ADDON"]),
                    Codigo = row["CODIGO"].ToString() ?? "",
                    Nombre = row["NOMBRE"].ToString() ?? "",
                    Descripcion = row["DESCRIPCION"]?.ToString() ?? "",
                    TipoLimite = row["TIPO_LIMITE"].ToString() ?? "",
                    Cantidad = Convert.ToInt32(row["CANTIDAD"]),
                    Precio = Convert.ToDecimal(row["PRECIO"]),
                    Icono = row["ICONO"]?.ToString() ?? "fa-plus",
                    Estado = true
                });
            }
            return addons;
        }

        private List<AddonLocal> MapearAddonsLocal(DataTable data)
        {
            List<AddonLocal> addons = new List<AddonLocal>();
            foreach (DataRow row in data.AsEnumerable())
            {
                addons.Add(new AddonLocal()
                {
                    Id = Convert.ToInt32(row["PK_ID"]),
                    IdLocal = Convert.ToInt32(row["FK_ID_LOCAL"]),
                    IdAddon = Convert.ToInt32(row["FK_ID_ADDON"]),
                    CantidadComprada = Convert.ToInt32(row["CANTIDAD_COMPRADA"]),
                    FechaCompra = Convert.ToDateTime(row["FECHA_COMPRA"]),
                    FechaExpiracion = row["FECHA_EXPIRACION"] != DBNull.Value
                        ? Convert.ToDateTime(row["FECHA_EXPIRACION"])
                        : (DateTime?)null,
                    RefPago = row["REF_PAGO"]?.ToString() ?? "",
                    Estado = Convert.ToInt32(row["ESTADO"]) == 1,
                    CodigoAddon = row["CODIGO"].ToString() ?? "",
                    NombreAddon = row["NOMBRE"].ToString() ?? "",
                    TipoLimite = row["TIPO_LIMITE"].ToString() ?? "",
                    CantidadAddon = Convert.ToInt32(row["CANTIDAD"]),
                    TotalAgregado = Convert.ToInt32(row["total_agregado"])
                });
            }
            return addons;
        }

        #endregion
    }
}
