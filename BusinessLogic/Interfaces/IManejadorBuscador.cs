using BusinessLogic.Models;
using BusinessLogic.Utilidades;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorBuscador
    {
        List<OfertaFlash> ConsultarOfertas(string query);
        List<Producto> ConsultarProductos(string query);
        List<Negocio> ConsultarLocales(string query);
        List<object> ConsultarLocalesSugerencias(string busqueda, int limite = 5);
        List<object> ConsultarProductosSugerencias(string busqueda, int limite = 5);
        List<object> ConsultarOfertasSugerencias(string busqueda, int limite = 3);
        List<SugerenciaBusqueda> ObtenerSugerenciasOrtograficas(string query);
    }
}
