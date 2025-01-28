using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DataAccess
{
    public class Transaccion
    {
        public string Procedimiento { get; set; }
        public List<Parametro> Parametros { get; set; }
    }
}
