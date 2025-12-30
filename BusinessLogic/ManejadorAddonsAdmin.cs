using BusinessLogic.Models;
using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;

namespace BusinessLogic
{
    /// <summary>
    /// Manejador para operaciones administrativas de addons
    /// </summary>
    public class ManejadorAddonsAdmin
    {
        private Connection conexion = new Connection();

        /// <summary>
        /// Obtiene todos los addons (incluyendo inactivos) para administración
        /// </summary>
        public List<AddonTipo> ObtenerTodosLosAddons()
        {
            DataTable data = conexion.EjecutarConsulta("obtener_todos_addons_admin");
            return MapearAddons(data);
        }

        /// <summary>
        /// Crea un nuevo addon
        /// </summary>
        public int CrearAddon(AddonTipo addon)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_codigo", addon.Codigo),
                new Parametro("p_nombre", addon.Nombre),
                new Parametro("p_descripcion", addon.Descripcion ?? ""),
                new Parametro("p_tipo_limite", addon.TipoLimite),
                new Parametro("p_cantidad", addon.Cantidad),
                new Parametro("p_precio", addon.Precio),
                new Parametro("p_icono", addon.Icono ?? "fa-plus")
            };

            DataTable data = conexion.EjecutarConsulta("crear_addon", parametros);

            if (data.Rows.Count > 0)
            {
                return Convert.ToInt32(data.Rows[0]["id_addon"]);
            }
            return 0;
        }

        /// <summary>
        /// Actualiza un addon existente
        /// </summary>
        public bool ActualizarAddon(AddonTipo addon)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id", addon.Id),
                new Parametro("p_codigo", addon.Codigo),
                new Parametro("p_nombre", addon.Nombre),
                new Parametro("p_descripcion", addon.Descripcion ?? ""),
                new Parametro("p_tipo_limite", addon.TipoLimite),
                new Parametro("p_cantidad", addon.Cantidad),
                new Parametro("p_precio", addon.Precio),
                new Parametro("p_icono", addon.Icono ?? "fa-plus")
            };

            return conexion.EjecutarTransaccion("actualizar_addon", parametros);
        }

        /// <summary>
        /// Cambia el estado de un addon (activar/desactivar)
        /// </summary>
        public bool CambiarEstadoAddon(int id, bool estado)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id", id),
                new Parametro("p_estado", estado ? 1 : 0)
            };

            return conexion.EjecutarTransaccion("cambiar_estado_addon", parametros);
        }

        /// <summary>
        /// Elimina un addon (solo si no tiene compras asociadas)
        /// </summary>
        public (bool Success, string Mensaje) EliminarAddon(int id)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id", id)
            };

            DataTable data = conexion.EjecutarConsulta("eliminar_addon", parametros);

            if (data.Rows.Count > 0)
            {
                int resultado = Convert.ToInt32(data.Rows[0]["resultado"]);
                string mensaje = data.Rows[0]["mensaje"]?.ToString() ?? "";
                return (resultado == 1, mensaje);
            }

            return (false, "Error al eliminar addon");
        }

        /// <summary>
        /// Obtiene estadísticas de ventas de addons
        /// </summary>
        public List<EstadisticaAddon> ObtenerEstadisticasAddons()
        {
            DataTable data = conexion.EjecutarConsulta("obtener_estadisticas_addons");
            List<EstadisticaAddon> estadisticas = new List<EstadisticaAddon>();

            foreach (DataRow row in data.Rows)
            {
                estadisticas.Add(new EstadisticaAddon
                {
                    IdAddon = Convert.ToInt32(row["id_addon"]),
                    NombreAddon = row["nombre"]?.ToString() ?? "",
                    TotalVentas = Convert.ToInt32(row["total_ventas"]),
                    CantidadTotal = Convert.ToInt32(row["cantidad_total"]),
                    IngresoTotal = Convert.ToDecimal(row["ingreso_total"])
                });
            }

            return estadisticas;
        }

        private List<AddonTipo> MapearAddons(DataTable data)
        {
            List<AddonTipo> addons = new List<AddonTipo>();
            foreach (DataRow row in data.Rows)
            {
                addons.Add(new AddonTipo()
                {
                    Id = Convert.ToInt32(row["PK_ID_ADDON"]),
                    Codigo = row["CODIGO"]?.ToString() ?? "",
                    Nombre = row["NOMBRE"]?.ToString() ?? "",
                    Descripcion = row["DESCRIPCION"]?.ToString() ?? "",
                    TipoLimite = row["TIPO_LIMITE"]?.ToString() ?? "",
                    Cantidad = Convert.ToInt32(row["CANTIDAD"]),
                    Precio = Convert.ToDecimal(row["PRECIO"]),
                    Icono = row["ICONO"]?.ToString() ?? "fa-plus",
                    Estado = Convert.ToInt32(row["ESTADO"]) == 1
                });
            }
            return addons;
        }
    }

    /// <summary>
    /// Modelo para estadísticas de ventas de addons
    /// </summary>
    public class EstadisticaAddon
    {
        public int IdAddon { get; set; }
        public string NombreAddon { get; set; } = "";
        public int TotalVentas { get; set; }
        public int CantidadTotal { get; set; }
        public decimal IngresoTotal { get; set; }
    }
}
