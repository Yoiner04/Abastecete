using System;

namespace BusinessLogic.Utilidades
{
    /// <summary>
    /// Plantillas HTML profesionales para correos electrónicos de Abastecete
    /// </summary>
    public static class EmailTemplates
    {
        private const string PrimaryColor = "#2563eb";
        private const string SecondaryColor = "#1e40af";
        private const string TextColor = "#374151";
        private const string LightGray = "#f3f4f6";
        private const string LogoUrl = "https://abastecete.com/images/logo.png";

        /// <summary>
        /// Plantilla base para todos los correos
        /// </summary>
        private static string GetBaseTemplate(string content, string preheader = "")
        {
            return $@"
<!DOCTYPE html>
<html lang=""es"">
<head>
    <meta charset=""UTF-8"">
    <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
    <meta http-equiv=""X-UA-Compatible"" content=""IE=edge"">
    <title>Abastecete</title>
    <!--[if mso]>
    <noscript>
        <xml>
            <o:OfficeDocumentSettings>
                <o:PixelsPerInch>96</o:PixelsPerInch>
            </o:OfficeDocumentSettings>
        </xml>
    </noscript>
    <![endif]-->
    <style>
        body {{
            margin: 0;
            padding: 0;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: {LightGray};
            -webkit-font-smoothing: antialiased;
        }}
        .container {{
            max-width: 600px;
            margin: 0 auto;
            background-color: #ffffff;
        }}
        .header {{
            background: linear-gradient(135deg, {PrimaryColor} 0%, {SecondaryColor} 100%);
            padding: 30px 40px;
            text-align: center;
        }}
        .header img {{
            max-width: 180px;
            height: auto;
        }}
        .header h1 {{
            color: #ffffff;
            margin: 15px 0 0 0;
            font-size: 24px;
            font-weight: 600;
        }}
        .content {{
            padding: 40px;
            color: {TextColor};
            line-height: 1.6;
        }}
        .footer {{
            background-color: {LightGray};
            padding: 30px 40px;
            text-align: center;
            color: #6b7280;
            font-size: 12px;
        }}
        .btn {{
            display: inline-block;
            padding: 14px 32px;
            background: linear-gradient(135deg, {PrimaryColor} 0%, {SecondaryColor} 100%);
            color: #ffffff !important;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            font-size: 16px;
            margin: 20px 0;
        }}
        .code-box {{
            background: linear-gradient(135deg, {LightGray} 0%, #e5e7eb 100%);
            border: 2px dashed {PrimaryColor};
            border-radius: 12px;
            padding: 25px;
            text-align: center;
            margin: 25px 0;
        }}
        .code {{
            font-size: 36px;
            font-weight: 700;
            letter-spacing: 8px;
            color: {PrimaryColor};
            font-family: 'Courier New', monospace;
        }}
        .warning {{
            background-color: #fef3c7;
            border-left: 4px solid #f59e0b;
            padding: 15px 20px;
            margin: 20px 0;
            border-radius: 0 8px 8px 0;
        }}
        .info {{
            background-color: #dbeafe;
            border-left: 4px solid {PrimaryColor};
            padding: 15px 20px;
            margin: 20px 0;
            border-radius: 0 8px 8px 0;
        }}
        .divider {{
            height: 1px;
            background-color: #e5e7eb;
            margin: 25px 0;
        }}
        .social-links {{
            margin: 20px 0;
        }}
        .social-links a {{
            display: inline-block;
            margin: 0 10px;
            color: {PrimaryColor};
            text-decoration: none;
        }}
        @media only screen and (max-width: 600px) {{
            .content {{
                padding: 25px !important;
            }}
            .code {{
                font-size: 28px !important;
                letter-spacing: 5px !important;
            }}
        }}
    </style>
</head>
<body>
    <div style=""display:none;max-height:0;overflow:hidden;"">{preheader}</div>
    <table role=""presentation"" width=""100%"" cellspacing=""0"" cellpadding=""0"" style=""background-color: {LightGray}; padding: 20px 0;"">
        <tr>
            <td align=""center"">
                <div class=""container"" style=""border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);"">
                    {content}
                </div>
            </td>
        </tr>
    </table>
</body>
</html>";
        }

        /// <summary>
        /// Obtiene el encabezado del correo
        /// </summary>
        private static string GetHeader(string title)
        {
            return $@"
                <div class=""header"">
                    <h1 style=""color: #ffffff; margin: 0; font-size: 28px; font-weight: 700;"">ABASTECETE</h1>
                    <p style=""color: rgba(255,255,255,0.9); margin: 10px 0 0 0; font-size: 14px;"">Tu marketplace de confianza</p>
                </div>";
        }

        /// <summary>
        /// Obtiene el pie de página del correo
        /// </summary>
        private static string GetFooter()
        {
            return $@"
                <div class=""footer"">
                    <p style=""margin: 0 0 10px 0; font-weight: 600; color: #374151;"">Abastecete Colombia</p>
                    <p style=""margin: 0 0 15px 0;"">Conectando proveedores y comerciantes</p>
                    <div class=""divider"" style=""margin: 15px auto; width: 50px;""></div>
                    <p style=""margin: 0; font-size: 11px; color: #9ca3af;"">
                        Este correo fue enviado desde una cuenta de correo no supervisada.<br>
                        Por favor no responda a este mensaje.
                    </p>
                    <p style=""margin: 15px 0 0 0; font-size: 11px; color: #9ca3af;"">
                        &copy; {DateTime.Now.Year} Abastecete. Todos los derechos reservados.
                    </p>
                </div>";
        }

        /// <summary>
        /// Plantilla para código de recuperación de contraseña
        /// </summary>
        public static string RecuperacionContrasenia(string nombreUsuario, string codigo)
        {
            string content = $@"
                {GetHeader("Recuperación de Contraseña")}
                <div class=""content"">
                    <h2 style=""color: {PrimaryColor}; margin: 0 0 20px 0; font-size: 22px;"">
                        Recupera tu contraseña
                    </h2>

                    <p>Hola{(string.IsNullOrEmpty(nombreUsuario) ? "" : $" <strong>{nombreUsuario}</strong>")},</p>

                    <p>Recibimos una solicitud para restablecer la contraseña de tu cuenta en Abastecete.
                    Usa el siguiente código para continuar con el proceso:</p>

                    <div class=""code-box"">
                        <p style=""margin: 0 0 10px 0; color: #6b7280; font-size: 14px;"">Tu código de verificación es:</p>
                        <div class=""code"">{codigo}</div>
                    </div>

                    <div class=""warning"">
                        <strong>Importante:</strong> Este código expirará en <strong>5 minutos</strong>.
                        Si no solicitaste este cambio, puedes ignorar este correo.
                    </div>

                    <div class=""divider""></div>

                    <p style=""font-size: 14px; color: #6b7280;"">
                        Si tienes problemas para usar el código, copia y pega el siguiente número en la página de recuperación:
                    </p>
                    <p style=""font-family: monospace; background-color: {LightGray}; padding: 10px 15px; border-radius: 6px; display: inline-block;"">
                        {codigo}
                    </p>
                </div>
                {GetFooter()}";

            return GetBaseTemplate(content, $"Tu código de recuperación es: {codigo}");
        }

        /// <summary>
        /// Plantilla para bienvenida de nuevo usuario
        /// </summary>
        public static string BienvenidaUsuario(string nombreUsuario, string correo)
        {
            string content = $@"
                {GetHeader("Bienvenido a Abastecete")}
                <div class=""content"">
                    <h2 style=""color: {PrimaryColor}; margin: 0 0 20px 0; font-size: 22px;"">
                        ¡Bienvenido a Abastecete!
                    </h2>

                    <p>Hola <strong>{nombreUsuario}</strong>,</p>

                    <p>Tu cuenta ha sido creada exitosamente. Ahora puedes acceder a nuestra plataforma
                    y comenzar a explorar productos de los mejores proveedores de Colombia.</p>

                    <div class=""info"">
                        <strong>Datos de tu cuenta:</strong><br>
                        Correo: <strong>{correo}</strong>
                    </div>

                    <div style=""text-align: center;"">
                        <a href=""https://abastecete.com"" class=""btn"">Comenzar a explorar</a>
                    </div>

                    <div class=""divider""></div>

                    <h3 style=""color: {TextColor}; font-size: 16px;"">¿Qué puedes hacer en Abastecete?</h3>
                    <ul style=""color: #6b7280; padding-left: 20px;"">
                        <li>Explorar productos de proveedores verificados</li>
                        <li>Comparar precios y ofertas</li>
                        <li>Contactar directamente con proveedores</li>
                        <li>Publicar tu propio negocio</li>
                    </ul>
                </div>
                {GetFooter()}";

            return GetBaseTemplate(content, $"¡Bienvenido a Abastecete, {nombreUsuario}!");
        }

        /// <summary>
        /// Plantilla para confirmación de cambio de contraseña
        /// </summary>
        public static string ContraseniaCambiada(string nombreUsuario)
        {
            string content = $@"
                {GetHeader("Contraseña Actualizada")}
                <div class=""content"">
                    <h2 style=""color: {PrimaryColor}; margin: 0 0 20px 0; font-size: 22px;"">
                        Contraseña actualizada correctamente
                    </h2>

                    <p>Hola{(string.IsNullOrEmpty(nombreUsuario) ? "" : $" <strong>{nombreUsuario}</strong>")},</p>

                    <p>Te confirmamos que tu contraseña ha sido actualizada exitosamente el
                    <strong>{DateTime.Now:dd/MM/yyyy}</strong> a las <strong>{DateTime.Now:HH:mm}</strong>.</p>

                    <div class=""info"">
                        Si realizaste este cambio, puedes ignorar este mensaje.
                        Tu cuenta está segura.
                    </div>

                    <div class=""warning"">
                        <strong>¿No fuiste tú?</strong><br>
                        Si no realizaste este cambio, te recomendamos contactar inmediatamente
                        a nuestro equipo de soporte para proteger tu cuenta.
                    </div>

                    <div style=""text-align: center;"">
                        <a href=""https://abastecete.com/login"" class=""btn"">Iniciar sesión</a>
                    </div>
                </div>
                {GetFooter()}";

            return GetBaseTemplate(content, "Tu contraseña ha sido actualizada");
        }

        /// <summary>
        /// Plantilla para notificación de contacto (enviada al admin)
        /// </summary>
        public static string NotificacionContacto(string emailRemitente, string telefono, string mensaje)
        {
            string content = $@"
                {GetHeader("Nuevo Mensaje de Contacto")}
                <div class=""content"">
                    <h2 style=""color: {PrimaryColor}; margin: 0 0 20px 0; font-size: 22px;"">
                        Nuevo mensaje de contacto
                    </h2>

                    <p>Se ha recibido un nuevo mensaje a través del formulario de contacto:</p>

                    <table style=""width: 100%; border-collapse: collapse; margin: 20px 0;"">
                        <tr>
                            <td style=""padding: 12px; background-color: {LightGray}; font-weight: 600; width: 120px; border-radius: 6px 0 0 0;"">Correo:</td>
                            <td style=""padding: 12px; background-color: {LightGray}; border-radius: 0 6px 0 0;"">{emailRemitente}</td>
                        </tr>
                        <tr>
                            <td style=""padding: 12px; font-weight: 600;"">Teléfono:</td>
                            <td style=""padding: 12px;"">(+57) {telefono}</td>
                        </tr>
                        <tr>
                            <td style=""padding: 12px; background-color: {LightGray}; font-weight: 600; border-radius: 0 0 0 6px;"">Fecha:</td>
                            <td style=""padding: 12px; background-color: {LightGray}; border-radius: 0 0 6px 0;"">{DateTime.Now:dd/MM/yyyy HH:mm}</td>
                        </tr>
                    </table>

                    <div class=""divider""></div>

                    <h3 style=""color: {TextColor}; font-size: 16px; margin-bottom: 10px;"">Mensaje:</h3>
                    <div style=""background-color: {LightGray}; padding: 20px; border-radius: 8px; border-left: 4px solid {PrimaryColor};"">
                        <p style=""margin: 0; white-space: pre-wrap;"">{mensaje}</p>
                    </div>

                    <div style=""text-align: center; margin-top: 25px;"">
                        <a href=""mailto:{emailRemitente}"" class=""btn"">Responder</a>
                    </div>
                </div>
                {GetFooter()}";

            return GetBaseTemplate(content, $"Nuevo mensaje de {emailRemitente}");
        }

        /// <summary>
        /// Plantilla para notificación de cuenta bloqueada
        /// </summary>
        public static string CuentaBloqueada(string nombreUsuario)
        {
            string content = $@"
                {GetHeader("Cuenta Bloqueada Temporalmente")}
                <div class=""content"">
                    <h2 style=""color: #dc2626; margin: 0 0 20px 0; font-size: 22px;"">
                        Tu cuenta ha sido bloqueada temporalmente
                    </h2>

                    <p>Hola{(string.IsNullOrEmpty(nombreUsuario) ? "" : $" <strong>{nombreUsuario}</strong>")},</p>

                    <p>Detectamos múltiples intentos fallidos de inicio de sesión en tu cuenta.
                    Por seguridad, hemos bloqueado temporalmente el acceso.</p>

                    <div class=""warning"">
                        <strong>Tu cuenta será desbloqueada automáticamente en 1 hora.</strong><br>
                        Si no fuiste tú quien intentó acceder, te recomendamos cambiar tu contraseña
                        una vez se desbloquee la cuenta.
                    </div>

                    <div class=""divider""></div>

                    <h3 style=""color: {TextColor}; font-size: 16px;"">Consejos de seguridad:</h3>
                    <ul style=""color: #6b7280; padding-left: 20px;"">
                        <li>Usa una contraseña única y segura</li>
                        <li>No compartas tus credenciales con nadie</li>
                        <li>Verifica que estés en el sitio oficial de Abastecete</li>
                    </ul>
                </div>
                {GetFooter()}";

            return GetBaseTemplate(content, "Aviso de seguridad: cuenta bloqueada temporalmente");
        }
    }
}
