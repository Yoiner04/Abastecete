using Newtonsoft.Json;

namespace BusinessLogic.Utilidades
{
    /// <summary>
    /// Helper para verificación de permisos del sistema
    /// Soporta tanto el sistema antiguo (por nombres) como el nuevo (por códigos)
    /// </summary>
    public static class RolPermisos
    {
        /// <summary>
        /// Verifica si el usuario tiene alguno de los permisos especificados
        /// Funciona tanto con el sistema antiguo (nombres) como el nuevo (códigos)
        /// </summary>
        /// <param name="permisosBuscar">Permisos a buscar separados por coma (ej: "ADMIN_USUARIOS,ADMIN_PERMISOS")</param>
        /// <param name="permisosJson">JSON con los permisos del usuario</param>
        /// <returns>True si tiene al menos uno de los permisos</returns>
        public static bool TienePermiso(string permisosBuscar, string permisosJson)
        {
            if (string.IsNullOrEmpty(permisosJson))
            {
                return false;
            }

            try
            {
                string[] arregloPermisos = permisosBuscar.Split(',', StringSplitOptions.RemoveEmptyEntries);
                Dictionary<string, bool> diccionarioPermisos = JsonConvert.DeserializeObject<Dictionary<string, bool>>(permisosJson);

                if (diccionarioPermisos == null)
                {
                    return false;
                }

                foreach (string permiso in arregloPermisos)
                {
                    string permisoLimpio = permiso.Trim();
                    if (diccionarioPermisos.TryGetValue(permisoLimpio, out bool tiene) && tiene)
                    {
                        return true;
                    }
                }
                return false;
            }
            catch
            {
                return false;
            }
        }

        /// <summary>
        /// Verifica si el usuario tiene TODOS los permisos especificados
        /// </summary>
        public static bool TieneTodosPermisos(string permisosBuscar, string permisosJson)
        {
            if (string.IsNullOrEmpty(permisosJson))
            {
                return false;
            }

            try
            {
                string[] arregloPermisos = permisosBuscar.Split(',', StringSplitOptions.RemoveEmptyEntries);
                Dictionary<string, bool> diccionarioPermisos = JsonConvert.DeserializeObject<Dictionary<string, bool>>(permisosJson);

                if (diccionarioPermisos == null)
                {
                    return false;
                }

                foreach (string permiso in arregloPermisos)
                {
                    string permisoLimpio = permiso.Trim();
                    if (!diccionarioPermisos.TryGetValue(permisoLimpio, out bool tiene) || !tiene)
                    {
                        return false;
                    }
                }
                return true;
            }
            catch
            {
                return false;
            }
        }

        /// <summary>
        /// Obtiene la lista de códigos de permisos que tiene el usuario
        /// </summary>
        public static List<string> ObtenerListaPermisos(string permisosJson)
        {
            if (string.IsNullOrEmpty(permisosJson))
            {
                return new List<string>();
            }

            try
            {
                Dictionary<string, bool> diccionarioPermisos = JsonConvert.DeserializeObject<Dictionary<string, bool>>(permisosJson);
                return diccionarioPermisos?
                    .Where(p => p.Value)
                    .Select(p => p.Key)
                    .ToList() ?? new List<string>();
            }
            catch
            {
                return new List<string>();
            }
        }

        /// <summary>
        /// Verifica si el usuario es administrador (tiene permisos ADMIN_*)
        /// </summary>
        public static bool EsAdministrador(string permisosJson)
        {
            if (string.IsNullOrEmpty(permisosJson))
            {
                return false;
            }

            try
            {
                Dictionary<string, bool> diccionarioPermisos = JsonConvert.DeserializeObject<Dictionary<string, bool>>(permisosJson);
                return diccionarioPermisos?.Any(p => p.Key.StartsWith("ADMIN_") && p.Value) ?? false;
            }
            catch
            {
                return false;
            }
        }
    }
}
