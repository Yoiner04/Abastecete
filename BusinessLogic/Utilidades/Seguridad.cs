using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

namespace BusinessLogic.Utilidades
{
    public static class Seguridad
    {
        private static readonly byte[] Key = Encoding.ASCII.GetBytes("StEryDroPlAtrIsT");
        private static readonly byte[] IV = Encoding.ASCII.GetBytes("nchSiTIsTABLEITY");

        /// <summary>
        /// Encripta una contraseña usando BCrypt (recomendado para contraseñas)
        /// </summary>
        public static string Encriptar(string Text)
        {
            if (string.IsNullOrEmpty(Text)) throw new ArgumentNullException("Text null");
            return BCrypt.Net.BCrypt.HashPassword(Text);
        }

        /// <summary>
        /// Verifica si una contraseña coincide con un hash BCrypt
        /// </summary>
        public static bool VerificarContrasenia(string contrasenia, string hashAlmacenado)
        {
            if (string.IsNullOrEmpty(contrasenia) || string.IsNullOrEmpty(hashAlmacenado))
                return false;

            try
            {
                return BCrypt.Net.BCrypt.Verify(contrasenia, hashAlmacenado);
            }
            catch
            {
                return false;
            }
        }

        /// <summary>
        /// Encripta texto usando AES (para datos que no son contraseñas)
        /// </summary>
        public static string EncriptarAES(string Text)
        {
            if (Text == null || Text.Length <= 0) throw new ArgumentNullException("Text null");
            if (Key == null || Key.Length <= 0) throw new ArgumentNullException("Key null");
            if (IV == null || IV.Length <= 0) throw new ArgumentNullException("Iv null");

            byte[] eData;
            using Aes aes = Aes.Create();
            aes.Key = Key;
            aes.IV = IV;
            using (MemoryStream ms = new MemoryStream())
            {
                using CryptoStream cs = new CryptoStream(ms, aes.CreateEncryptor(aes.Key, aes.IV), CryptoStreamMode.Write);
                using (StreamWriter sw = new StreamWriter(cs))
                {
                    sw.Write(Text);
                }
                eData = ms.ToArray();
            }
            string edta = Convert.ToBase64String(eData);
            return edta;
        }

        /// <summary>
        /// Desencripta texto usando AES
        /// </summary>
        public static string Desencriptar(string Text)
        {
            byte[] cText = Convert.FromBase64String(Text);
            if (cText == null || cText.Length <= 0) throw new ArgumentNullException("Text null");
            if (Key == null || Key.Length <= 0) throw new ArgumentNullException("Key null");
            if (IV == null || IV.Length <= 0) throw new ArgumentNullException("Iv null");

            string dData;
            using (Aes aes = Aes.Create())
            {
                aes.Key = Key;
                aes.IV = IV;

                using MemoryStream ms = new MemoryStream(cText);
                using CryptoStream cs = new CryptoStream(ms, aes.CreateDecryptor(aes.Key, aes.IV), CryptoStreamMode.Read);
                using StreamReader sr = new StreamReader(cs);
                dData = sr.ReadToEnd();
            }
            return dData;
        }
    }
}
