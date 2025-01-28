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

        public static string Encriptar(string Text)
        {
            if (Text == null || Text.Length <= 0) throw new ArgumentNullException("Text null");
            if (Key == null || Key.Length <= 0) throw new ArgumentNullException("Key null");
            if (IV == null || IV.Length <= 0) throw new ArgumentNullException("Iv null");

            byte[] eData;
            using Rijndael r = Rijndael.Create();
            r.Key = Key;
            r.IV = IV;
            using (MemoryStream ms = new MemoryStream())
            {
                using CryptoStream cs = new CryptoStream(ms, r.CreateEncryptor(r.Key, r.IV), CryptoStreamMode.Write);
                using (StreamWriter sw = new StreamWriter(cs))
                {
                    sw.Write(Text);
                }
                eData = ms.ToArray();
            }
            string edta = Convert.ToBase64String(eData);
            return edta;
        }

        public static string Desencriptar(string Text)
        {
            byte[] cText = Convert.FromBase64String(Text);
            if (cText == null || cText.Length <= 0) throw new ArgumentNullException("Text null");
            if (Key == null || Key.Length <= 0) throw new ArgumentNullException("Key null");
            if (IV == null || IV.Length <= 0) throw new ArgumentNullException("Iv null");

            string dData;
            using (Rijndael r = Rijndael.Create())
            {
                r.Key = Key;
                r.IV = IV;

                using MemoryStream ms = new MemoryStream(cText);
                using CryptoStream cs = new CryptoStream(ms, r.CreateDecryptor(r.Key, r.IV), CryptoStreamMode.Read);
                using StreamReader sr = new StreamReader(cs);
                dData = sr.ReadToEnd();
            }
            return dData;
        }
    }
}
