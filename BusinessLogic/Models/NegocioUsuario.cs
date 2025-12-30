using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BusinessLogic.Models
{
    /// <summary>
    /// ViewModel que combina un Usuario con su Negocio
    /// </summary>
    public class NegocioUsuario
    {
        public Usuario? Usuario { get; set; }
        public Negocio? Negocio { get; set; }
    }

    /// <summary>
    /// Alias para compatibilidad con código existente
    /// TODO: Eliminar después de migrar todo el código
    /// </summary>
    public class NegocioPersona
    {
        public Usuario? Persona { get; set; }
        public Negocio? Negocio { get; set; }
    }
}
