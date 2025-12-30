using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BusinessLogic.Models
{
    public class PermisosViewModel
    {
        public Rol? Rol { get; set; }
        public Usuario? Usuario { get; set; }
        public Permiso? Permiso { get; set; }
    }
}
