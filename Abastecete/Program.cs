using BusinessLogic;
using BusinessLogic.Utilidades;
using BusinessLogic.Interfaces;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.Google;
using BusinessLogic.Models;
using DataAccess;
using MongoDB.Driver;
using DataAccess.Interface;
using Microsoft.AspNetCore.DataProtection;

var builder = WebApplication.CreateBuilder(args);

// Configurar Data Protection para persistir las claves
var keysDirectory = Path.Combine(builder.Environment.ContentRootPath, "keys");
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo(keysDirectory))
    .SetApplicationName("Abastecete");

builder.Services.AddDistributedMemoryCache();


builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromMinutes(10);
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
});
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = CookieAuthenticationDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = GoogleDefaults.AuthenticationScheme;
})
.AddCookie()
.AddGoogle(options =>
{
    options.ClientId = builder.Configuration["Google:ClientId"] ?? "";
    options.ClientSecret = builder.Configuration["Google:ClientSecret"] ?? "";
    options.CallbackPath = "/signin-google";
    options.SaveTokens = true;
    // Obtener foto de perfil desde Google API
    options.Events.OnCreatingTicket = async context =>
    {
        var request = new HttpRequestMessage(HttpMethod.Get, "https://www.googleapis.com/oauth2/v2/userinfo");
        request.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", context.AccessToken);
        var response = await context.Backchannel.SendAsync(request);
        if (response.IsSuccessStatusCode)
        {
            var json = await response.Content.ReadAsStringAsync();
            var user = System.Text.Json.JsonDocument.Parse(json);
            if (user.RootElement.TryGetProperty("picture", out var picture))
            {
                context.Identity?.AddClaim(new System.Security.Claims.Claim("picture", picture.GetString() ?? ""));
            }
        }
    };
});

builder.Services.AddScoped<IEpaycoService, EpaycoService>();
builder.Services.AddScoped<IMongoConnection, MongoConnection>();

// Registrar Manejadores con DI
builder.Services.AddScoped<IManejadorUsuario, ManejadorUsuario>();
builder.Services.AddScoped<IManejadorNegocios, ManejadorNegocios>();
builder.Services.AddScoped<IManejadorCategorias, ManejadorCategorias>();
builder.Services.AddScoped<IManejadorImagenes, ManejadorImagenes>();
builder.Services.AddScoped<IManejadorOfertasFlash, ManejadorOfertasFlash>();
builder.Services.AddScoped<IManejadorBuscador, ManejadorBuscador>();
builder.Services.AddScoped<IEmailService, EmailService>();
builder.Services.AddScoped<IManejadorProductos, ManejadorProductos>();
builder.Services.AddScoped<IManejadorAnaliticas, ManejadorAnaliticas>();
builder.Services.AddScoped<IManejadorLogs, ManejadorLogs>();
builder.Services.AddScoped<IManejadorPermisos, ManejadorPermisos>();
builder.Services.AddScoped<IManejadorMembresias, ManejadorMembresias>();
builder.Services.AddScoped<IManejadorMarcas, ManejadorMarcas>();
builder.Services.AddScoped<IManejadorOpiniones, ManejadorOpiniones>();
builder.Services.AddScoped<IManejadorSuscripciones, ManejadorSuscripciones>();
builder.Services.AddScoped<IManejadorGaleriaLocal, ManejadorGaleriaLocal>();
builder.Services.AddScoped<IManejadorProductoMarca, ManejadorProductoMarca>();
builder.Services.AddScoped<IManejadorSubCategorias, ManejadorSubCategorias>();
builder.Services.AddScoped<IManejadorTipoUnidad, ManejadorTipoUnidad>();
builder.Services.AddScoped<IManejadorUnidad, ManejadorUnidad>();
builder.Services.AddScoped<IManejadorTipoDocumento, ManejadorTipoDocumento>();
builder.Services.AddScoped<IManejadorAddons, ManejadorAddons>();
builder.Services.AddScoped<IManejadorAddonsAdmin, ManejadorAddonsAdmin>();
builder.Services.AddScoped<IManejadorReferidos, ManejadorReferidos>();

builder.Services.AddHttpContextAccessor();
builder.Services.AddControllersWithViews();

var app = builder.Build();

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

// Activar autenticaci�n y autorizaci�n
app.UseAuthentication();
app.UseAuthorization();
app.UseSession();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Principal}");

app.Run();


