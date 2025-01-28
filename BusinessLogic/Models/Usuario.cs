namespace BusinessLogic.Models

{
    public class Usuario
    {
        public int Id { get; set; }
        public string Correo { get; set; }

        public string Contrasenia { get; set; }

        public int CodigoReferido { get; set; }

        public Rol Rol { get; set; }

        public Persona Persona { get; set; }

    }
}
