using System;
using System.Collections.Generic;
using System.Linq;

namespace BusinessLogic.Utilidades
{
    /// <summary>
    /// Utilidades para calcular similitud de texto y sugerir correcciones ortográficas
    /// </summary>
    public static class StringSimilarity
    {
        /// <summary>
        /// Calcula la distancia de Levenshtein entre dos cadenas
        /// (número mínimo de operaciones para transformar una cadena en otra)
        /// </summary>
        public static int LevenshteinDistance(string source, string target)
        {
            if (string.IsNullOrEmpty(source))
                return string.IsNullOrEmpty(target) ? 0 : target.Length;
            if (string.IsNullOrEmpty(target))
                return source.Length;

            source = source.ToLowerInvariant();
            target = target.ToLowerInvariant();

            int sourceLength = source.Length;
            int targetLength = target.Length;

            var distance = new int[sourceLength + 1, targetLength + 1];

            for (int i = 0; i <= sourceLength; i++)
                distance[i, 0] = i;
            for (int j = 0; j <= targetLength; j++)
                distance[0, j] = j;

            for (int i = 1; i <= sourceLength; i++)
            {
                for (int j = 1; j <= targetLength; j++)
                {
                    int cost = (source[i - 1] == target[j - 1]) ? 0 : 1;
                    distance[i, j] = Math.Min(
                        Math.Min(distance[i - 1, j] + 1, distance[i, j - 1] + 1),
                        distance[i - 1, j - 1] + cost);
                }
            }

            return distance[sourceLength, targetLength];
        }

        /// <summary>
        /// Calcula el porcentaje de similitud entre dos cadenas (0-100)
        /// </summary>
        public static double SimilarityPercentage(string source, string target)
        {
            if (string.IsNullOrEmpty(source) && string.IsNullOrEmpty(target))
                return 100;
            if (string.IsNullOrEmpty(source) || string.IsNullOrEmpty(target))
                return 0;

            int maxLength = Math.Max(source.Length, target.Length);
            int distance = LevenshteinDistance(source, target);

            return (1.0 - (double)distance / maxLength) * 100;
        }

        /// <summary>
        /// Encuentra las mejores coincidencias de una consulta en una lista de términos
        /// </summary>
        /// <param name="query">Término buscado por el usuario</param>
        /// <param name="candidates">Lista de términos candidatos (nombres de productos, negocios, etc.)</param>
        /// <param name="minSimilarity">Porcentaje mínimo de similitud (default 50%)</param>
        /// <param name="maxResults">Número máximo de resultados (default 3)</param>
        /// <returns>Lista de sugerencias ordenadas por similitud</returns>
        public static List<SugerenciaBusqueda> FindBestMatches(
            string query,
            IEnumerable<string> candidates,
            double minSimilarity = 50,
            int maxResults = 3)
        {
            if (string.IsNullOrWhiteSpace(query) || candidates == null)
                return new List<SugerenciaBusqueda>();

            query = query.Trim().ToLowerInvariant();

            var suggestions = candidates
                .Where(c => !string.IsNullOrWhiteSpace(c))
                .Select(c => new
                {
                    Original = c,
                    Normalized = c.Trim().ToLowerInvariant(),
                    Similarity = SimilarityPercentage(query, c.Trim())
                })
                .Where(x => x.Similarity >= minSimilarity && x.Normalized != query)
                .OrderByDescending(x => x.Similarity)
                .ThenBy(x => x.Normalized.Length) // Preferir términos más cortos
                .Take(maxResults)
                .Select(x => new SugerenciaBusqueda
                {
                    Termino = x.Original,
                    Similitud = x.Similarity
                })
                .ToList();

            return suggestions;
        }

        /// <summary>
        /// Encuentra la mejor coincidencia única
        /// </summary>
        public static string? FindBestMatch(string query, IEnumerable<string> candidates, double minSimilarity = 60)
        {
            var matches = FindBestMatches(query, candidates, minSimilarity, 1);
            return matches.FirstOrDefault()?.Termino;
        }

        /// <summary>
        /// Verifica si dos cadenas son similares (para detectar errores tipográficos)
        /// </summary>
        public static bool AreSimilar(string s1, string s2, double threshold = 70)
        {
            return SimilarityPercentage(s1, s2) >= threshold;
        }

        /// <summary>
        /// Normaliza un texto para búsqueda (quita acentos, espacios extra, etc.)
        /// </summary>
        public static string NormalizeForSearch(string text)
        {
            if (string.IsNullOrWhiteSpace(text))
                return string.Empty;

            text = text.Trim().ToLowerInvariant();

            // Quitar acentos
            var normalizedString = text.Normalize(System.Text.NormalizationForm.FormD);
            var stringBuilder = new System.Text.StringBuilder();

            foreach (var c in normalizedString)
            {
                var unicodeCategory = System.Globalization.CharUnicodeInfo.GetUnicodeCategory(c);
                if (unicodeCategory != System.Globalization.UnicodeCategory.NonSpacingMark)
                {
                    stringBuilder.Append(c);
                }
            }

            return stringBuilder.ToString().Normalize(System.Text.NormalizationForm.FormC);
        }
    }

    /// <summary>
    /// Representa una sugerencia de búsqueda con su porcentaje de similitud
    /// </summary>
    public class SugerenciaBusqueda
    {
        public string Termino { get; set; } = string.Empty;
        public double Similitud { get; set; }
    }
}
