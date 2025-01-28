using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DataAccess
{
    public class Parametro
    {
        public string Nombre { get; set; }
        public object Valor { get; set; }

        public Parametro(string Nombre, object Valor)
        {
            this.Nombre = Nombre;
            this.Valor = Valor;
        }
    }
}
