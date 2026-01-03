using BusinessLogic.Models;
using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BusinessLogic
{
    public class ManejadorTipoDocumento : Interfaces.IManejadorTipoDocumento
    {
        private Connection conexion = new Connection();

        public ManejadorTipoDocumento()
        {
            conexion = new Connection();
        }

        public List<TipoDocumento> ObtenerTipoDocumentos()
        {
            DataTable data = conexion.EjecutarConsulta("consultar_tipo_documento");
            List<TipoDocumento> tipoDocumentos = new List<TipoDocumento>();
            foreach (DataRow row in data.AsEnumerable())
            {
                tipoDocumentos.Add(new TipoDocumento()
                {
                    Id = Convert.ToInt32(row["PK_ID_TIPO_DOCUMENTO"].ToString()),
                    Nombre = row["NOMBRE_TIPO_DOCUMENTO"].ToString() ?? ""
                });
            }
            return tipoDocumentos;
        }
    }
}
