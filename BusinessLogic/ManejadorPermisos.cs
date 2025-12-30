using BusinessLogic.Models;
using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;

namespace BusinessLogic
{
    public class ManejadorPermisos
    {
        private Connection conexion = new Connection();

        #region Sistema de Permisos

        /// <summary>
        /// Obtiene todos los permisos del sistema (catálogo completo)
        /// </summary>
        public List<PermisoSistema> ObtenerTodosPermisosSistema()
        {
            DataTable data = conexion.EjecutarConsulta("obtener_permisos_sistema");
            return MapearPermisosSistema(data);
        }

        /// <summary>
        /// Obtiene los permisos de una membresía (plantilla)
        /// </summary>
        public List<PermisoSistema> ObtenerPermisosMembresia(int idTipoMembresia)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id_tipo_membresia", idTipoMembresia)
            };
            DataTable data = conexion.EjecutarConsulta("obtener_permisos_membresia", parametros);
            return MapearPermisosSistema(data);
        }

        /// <summary>
        /// Obtiene los permisos efectivos de un usuario
        /// </summary>
        public List<PermisoSistema> ObtenerPermisosUsuario(int idUsuario)
        {
            var sw = System.Diagnostics.Stopwatch.StartNew();
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id_usuario", idUsuario)
            };
            DataTable data = conexion.EjecutarConsulta("obtener_permisos_usuario", parametros);
            Console.WriteLine($"[PERMISOS TIMING] SP obtener_permisos_usuario: {sw.ElapsedMilliseconds}ms, filas: {data.Rows.Count}");
            sw.Restart();
            var result = MapearPermisosUsuario(data);
            Console.WriteLine($"[PERMISOS TIMING] Mapeo: {sw.ElapsedMilliseconds}ms");
            return result;
        }

        /// <summary>
        /// Verifica si un usuario tiene un permiso específico
        /// </summary>
        public bool TienePermiso(int idUsuario, string codigoPermiso)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id_usuario", idUsuario),
                new Parametro("p_codigo_permiso", codigoPermiso)
            };
            DataTable data = conexion.EjecutarConsulta("verificar_permiso_usuario", parametros);

            if (data.Rows.Count > 0)
            {
                return Convert.ToBoolean(data.Rows[0]["tiene_permiso"]);
            }
            return false;
        }

        /// <summary>
        /// Asigna los permisos de una membresía a un usuario (reemplaza permisos con origen MEMBRESIA)
        /// </summary>
        public int AsignarPermisosDeMembresia(int idUsuario, int idTipoMembresia)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id_usuario", idUsuario),
                new Parametro("p_id_tipo_membresia", idTipoMembresia)
            };
            DataTable data = conexion.EjecutarConsulta("asignar_permisos_membresia_usuario", parametros);

            if (data.Rows.Count > 0)
            {
                return Convert.ToInt32(data.Rows[0]["permisos_asignados"]);
            }
            return 0;
        }

        /// <summary>
        /// Asigna un permiso individual a un usuario (usado por admin)
        /// </summary>
        public bool AsignarPermisoUsuario(int idUsuario, int idPermiso, string origen = "ADMIN")
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id_usuario", idUsuario),
                new Parametro("p_id_permiso", idPermiso),
                new Parametro("p_origen", origen)
            };
            DataTable data = conexion.EjecutarConsulta("asignar_permiso_usuario", parametros);
            return data.Rows.Count > 0 && Convert.ToInt32(data.Rows[0]["resultado"]) > 0;
        }

        /// <summary>
        /// Remueve un permiso de un usuario (desactiva)
        /// </summary>
        public bool RemoverPermisoUsuario(int idUsuario, int idPermiso)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id_usuario", idUsuario),
                new Parametro("p_id_permiso", idPermiso)
            };
            DataTable data = conexion.EjecutarConsulta("remover_permiso_usuario", parametros);
            return data.Rows.Count > 0 && Convert.ToInt32(data.Rows[0]["resultado"]) > 0;
        }

        /// <summary>
        /// Actualiza los permisos de una membresía (plantilla)
        /// </summary>
        public int ActualizarPermisosMembresia(int idTipoMembresia, List<int> idsPermisos)
        {
            string idsString = idsPermisos != null && idsPermisos.Count > 0
                ? string.Join(",", idsPermisos)
                : "";

            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id_tipo_membresia", idTipoMembresia),
                new Parametro("p_ids_permisos", idsString)
            };
            DataTable data = conexion.EjecutarConsulta("actualizar_permisos_membresia", parametros);

            if (data.Rows.Count > 0)
            {
                return Convert.ToInt32(data.Rows[0]["permisos_asignados"]);
            }
            return 0;
        }

        /// <summary>
        /// Obtiene permisos del sistema agrupados por categoría
        /// </summary>
        public Dictionary<string, List<PermisoSistema>> ObtenerPermisosAgrupados()
        {
            var permisos = ObtenerTodosPermisosSistema();
            return permisos.GroupBy(p => p.Categoria)
                          .ToDictionary(g => g.Key, g => g.ToList());
        }

        /// <summary>
        /// Obtiene un diccionario de permisos del usuario para almacenar en sesión
        /// Incluye permisos básicos por defecto para todos los usuarios logueados
        /// </summary>
        public Dictionary<string, bool> ObtenerDiccionarioPermisos(int idUsuario)
        {
            var permisos = ObtenerPermisosUsuario(idUsuario);
            var diccionario = permisos.ToDictionary(p => p.Codigo, p => p.Estado);

            // Permisos básicos para todos los usuarios logueados (sin importar si tienen negocio)
            if (!diccionario.ContainsKey("Publica tu negocio"))
                diccionario["Publica tu negocio"] = true;
            if (!diccionario.ContainsKey("Dejanos tu reseña"))
                diccionario["Dejanos tu reseña"] = true;

            return diccionario;
        }

        #endregion

        #region Métodos de Mapeo

        private List<PermisoSistema> MapearPermisosSistema(DataTable data)
        {
            List<PermisoSistema> permisos = new List<PermisoSistema>();
            foreach (DataRow row in data.AsEnumerable())
            {
                permisos.Add(new PermisoSistema()
                {
                    Id = Convert.ToInt32(row["PK_ID_PERMISO"]),
                    Codigo = row["CODIGO"]?.ToString() ?? "",
                    Nombre = row["NOMBRE"]?.ToString() ?? "",
                    Descripcion = row["DESCRIPCION"]?.ToString() ?? "",
                    Icono = row["ICONO"]?.ToString() ?? "fa-check",
                    Categoria = row["CATEGORIA"]?.ToString() ?? "",
                    Orden = Convert.ToInt32(row["ORDEN"]),
                    Estado = true
                });
            }
            return permisos;
        }

        private List<PermisoSistema> MapearPermisosUsuario(DataTable data)
        {
            List<PermisoSistema> permisos = new List<PermisoSistema>();
            foreach (DataRow row in data.AsEnumerable())
            {
                permisos.Add(new PermisoSistema()
                {
                    Id = Convert.ToInt32(row["PK_ID_PERMISO"]),
                    Codigo = row["CODIGO"]?.ToString() ?? "",
                    Nombre = row["NOMBRE"]?.ToString() ?? "",
                    Descripcion = row["DESCRIPCION"]?.ToString() ?? "",
                    Icono = row["ICONO"]?.ToString() ?? "fa-check",
                    Categoria = row["CATEGORIA"]?.ToString() ?? "",
                    Orden = Convert.ToInt32(row["ORDEN"]),
                    Origen = row["ORIGEN"]?.ToString() ?? "MEMBRESIA",
                    FechaAsignacion = row["FECHA_ASIGNACION"] != DBNull.Value
                        ? Convert.ToDateTime(row["FECHA_ASIGNACION"])
                        : (DateTime?)null,
                    Estado = Convert.ToInt32(row["ESTADO"]) == 1
                });
            }
            return permisos;
        }

        #endregion
    }
}
