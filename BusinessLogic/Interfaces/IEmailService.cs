namespace BusinessLogic.Interfaces
{
    public interface IEmailService
    {
        Task<(bool Success, string Message)> EnviarCodigoRecuperacion(string destinatario, string nombreUsuario, string codigo);
    }
}
