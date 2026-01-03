using BusinessLogic.Models;
using System.Data;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorUsuario
    {
        bool RegistrarUsuario(Usuario usuario);
        (bool exito, string mensaje) RegistrarUsuarioConMensaje(Usuario usuario);
        DataTable Login(string nombreUsuario, string contrasenia);
        DataTable LoginGoogle(string correo);
        int RegistrarUsuarioGoogle(string correo, string nombre, string pictureUrl);
        bool ActualizarFotoPerfil(int idUsuario, string pictureUrl);
        DataTable ObtenerUsuarioPorCorreo(string correo);
        void GenerarTokenRecuperacion(int userId);
        string? ObtenerTokenRecuperacion(int userId);
        DataTable ValidarTokenRecuperacion(string token);
        bool ValidarToken(string token, out int userId);
        bool CambiarContrasenia(int userId, string nuevaContrasenia);
        List<Usuario> ConsultarUsuarios(int idUsuario);
        List<Usuario> ObtenerUsuarios(int idUsuario);
        (bool exito, string mensaje) CambiarContraseniaVerificada(int userId, string contraseniaActual, string nuevaContrasenia);
        bool EditarEstadoUsuario(int idUsuario, int nuevoEstado);
        bool EditarUsuario(Usuario usuario);
        ResultadoPaginado<UsuarioConLocalViewModel> ConsultarUsuariosPaginado(int pagina, int registrosPorPagina, string? busqueda = null);
    }
}
