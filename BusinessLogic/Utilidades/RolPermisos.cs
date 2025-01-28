using Newtonsoft.Json;


namespace BusinessLogic.Utilidades
{
    public static class RolPermisos
    {
        //public static bool TienePermiso(string permisosBuscar, string permisos)
        //{
        //    bool result = false;
        //    string[] arregloPermisos = permisosBuscar.Split(",");
        //    Dictionary<string, bool> diccionarioPermisos = JsonConvert.DeserializeObject<Dictionary<string, bool>>(permisos);
        //    foreach (string permiso in arregloPermisos)
        //    {
        //        diccionarioPermisos.TryGetValue(permiso, out result);
        //        if (result == true)
        //        {
        //            break;
        //        }
        //    }
        //    return result;
        //}

        public static bool TienePermiso(string permisosBuscar, string permisos)
        {
            if (string.IsNullOrEmpty(permisos))
            {
                return false; // Sin permisos, retorna falso
            }

            try
            {
                bool result = false;
                string[] arregloPermisos = permisosBuscar.Split(",");
                Dictionary<string, bool> diccionarioPermisos = JsonConvert.DeserializeObject<Dictionary<string, bool>>(permisos);

                foreach (string permiso in arregloPermisos)
                {
                    if (diccionarioPermisos.TryGetValue(permiso, out result) && result)
                    {
                        return true; // Si se encuentra un permiso válido, retorna verdadero
                    }
                }
                return false; // Si no se encuentra ningún permiso, retorna falso
            }
            catch
            {
                return false; // En caso de error en la deserialización, retorna falso
            }
        }

    }
}
