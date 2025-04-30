using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using DataAccess.Interface;
using Microsoft.Extensions.Configuration;
using MongoDB.Driver;
using MongoDB.Driver.GridFS;

namespace DataAccess
{
    public class MongoConnection : IMongoConnection
    {
        private readonly IMongoDatabase _database;

        public MongoConnection(IConfiguration config)
        {
            var client = new MongoClient(config.GetConnectionString("MongoDb"));
            _database = client.GetDatabase("abastecete");
        }

        public IMongoDatabase GetDatabase() => _database;
    }
}
