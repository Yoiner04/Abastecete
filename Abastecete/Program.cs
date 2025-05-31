using BusinessLogic.Utilidades;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.Google;
using BusinessLogic.Interfaces;
using BusinessLogic.Models;
using DataAccess;
using MongoDB.Driver;
using DataAccess.Interface;
using Microsoft.AspNetCore.HttpOverrides;

var builder = WebApplication.CreateBuilder(args);
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
    options.ClientId = "169045921628-am6cj2hhhpkthrqckqp3k9l667kp7ahb.apps.googleusercontent.com";
    options.ClientSecret = "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";
    options.CallbackPath = "/signin-google";
});

builder.Services.AddScoped<IEpaycoService, EpaycoService>();

builder.Services.AddScoped<IMongoConnection, MongoConnection>();


builder.Services.AddDistributedMemoryCache();


builder.Services.AddHttpContextAccessor();
builder.Services.AddControllersWithViews();


var app = builder.Build();

builder.WebHost.ConfigureKestrel(serverOptions =>
{
    serverOptions.AddServerHeader = false;
});

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.KnownNetworks.Clear(); // Permitir cualquier IP de proxy
    options.KnownProxies.Clear();
});


app.UseForwardedHeaders();
app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

// Activar autenticación y autorización
app.UseAuthentication();
app.UseAuthorization();
app.UseSession();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Principal}");

app.Run();


