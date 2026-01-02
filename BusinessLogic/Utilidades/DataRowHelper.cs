using System;
using System.Data;

namespace BusinessLogic.Utilidades
{
    /// <summary>
    /// Helper para acceso seguro a columnas de DataRow
    /// Evita NullReferenceException y maneja DBNull correctamente
    /// </summary>
    public static class DataRowHelper
    {
        /// <summary>
        /// Obtiene un string de forma segura, retornando valor por defecto si es null o no existe
        /// </summary>
        public static string GetString(DataRow row, string columnName, string defaultValue = "")
        {
            if (!row.Table.Columns.Contains(columnName) || row[columnName] == DBNull.Value || row[columnName] == null)
                return defaultValue;
            return row[columnName].ToString() ?? defaultValue;
        }

        /// <summary>
        /// Obtiene un long de forma segura
        /// </summary>
        public static long GetLong(DataRow row, string columnName, long defaultValue = 0)
        {
            if (!row.Table.Columns.Contains(columnName) || row[columnName] == DBNull.Value || row[columnName] == null)
                return defaultValue;
            return Convert.ToInt64(row[columnName]);
        }

        /// <summary>
        /// Obtiene un long nullable de forma segura
        /// </summary>
        public static long? GetLongNullable(DataRow row, string columnName)
        {
            if (!row.Table.Columns.Contains(columnName) || row[columnName] == DBNull.Value || row[columnName] == null)
                return null;
            return Convert.ToInt64(row[columnName]);
        }

        /// <summary>
        /// Obtiene un int de forma segura
        /// </summary>
        public static int GetInt(DataRow row, string columnName, int defaultValue = 0)
        {
            if (!row.Table.Columns.Contains(columnName) || row[columnName] == DBNull.Value || row[columnName] == null)
                return defaultValue;
            return Convert.ToInt32(row[columnName]);
        }

        /// <summary>
        /// Obtiene un int nullable de forma segura
        /// </summary>
        public static int? GetIntNullable(DataRow row, string columnName)
        {
            if (!row.Table.Columns.Contains(columnName) || row[columnName] == DBNull.Value || row[columnName] == null)
                return null;
            return Convert.ToInt32(row[columnName]);
        }

        /// <summary>
        /// Obtiene un decimal de forma segura
        /// </summary>
        public static decimal GetDecimal(DataRow row, string columnName, decimal defaultValue = 0)
        {
            if (!row.Table.Columns.Contains(columnName) || row[columnName] == DBNull.Value || row[columnName] == null)
                return defaultValue;
            return Convert.ToDecimal(row[columnName]);
        }

        /// <summary>
        /// Obtiene un decimal nullable de forma segura
        /// </summary>
        public static decimal? GetDecimalNullable(DataRow row, string columnName)
        {
            if (!row.Table.Columns.Contains(columnName) || row[columnName] == DBNull.Value || row[columnName] == null)
                return null;
            return Convert.ToDecimal(row[columnName]);
        }

        /// <summary>
        /// Obtiene un bool de forma segura
        /// </summary>
        public static bool GetBool(DataRow row, string columnName, bool defaultValue = false)
        {
            if (!row.Table.Columns.Contains(columnName) || row[columnName] == DBNull.Value || row[columnName] == null)
                return defaultValue;

            var value = row[columnName];
            if (value is bool boolValue)
                return boolValue;
            if (value is int intValue)
                return intValue != 0;
            if (value is string strValue)
                return strValue == "1" || strValue.Equals("true", StringComparison.OrdinalIgnoreCase);

            return Convert.ToBoolean(value);
        }

        /// <summary>
        /// Obtiene un DateTime de forma segura
        /// </summary>
        public static DateTime GetDateTime(DataRow row, string columnName, DateTime? defaultValue = null)
        {
            if (!row.Table.Columns.Contains(columnName) || row[columnName] == DBNull.Value || row[columnName] == null)
                return defaultValue ?? DateTime.MinValue;
            return Convert.ToDateTime(row[columnName]);
        }

        /// <summary>
        /// Obtiene un DateTime nullable de forma segura
        /// </summary>
        public static DateTime? GetDateTimeNullable(DataRow row, string columnName)
        {
            if (!row.Table.Columns.Contains(columnName) || row[columnName] == DBNull.Value || row[columnName] == null)
                return null;
            return Convert.ToDateTime(row[columnName]);
        }

        /// <summary>
        /// Verifica si una columna existe y tiene valor (no es null ni DBNull)
        /// </summary>
        public static bool HasValue(DataRow row, string columnName)
        {
            return row.Table.Columns.Contains(columnName)
                && row[columnName] != DBNull.Value
                && row[columnName] != null;
        }
    }
}
