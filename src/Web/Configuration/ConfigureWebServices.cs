using Microsoft.eShopWeb.ApplicationCore;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.eShopWeb.ApplicationCore.Services;
using Microsoft.eShopWeb.Web.Interfaces;
using Microsoft.eShopWeb.Web.Services;

namespace Microsoft.eShopWeb.Web.Configuration;

public static class ConfigureWebServices
{
    public static IServiceCollection AddWebServices(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddMediatR(cfg => 
            cfg.RegisterServicesFromAssembly(typeof(BasketViewModelService).Assembly));
        services.AddScoped<IBasketViewModelService, BasketViewModelService>();
        services.AddScoped<CatalogViewModelService>();
        services.AddScoped<ICatalogItemViewModelService, CatalogItemViewModelService>();
        services.Configure<CatalogSettings>(configuration);

        /*var featuresSection = configuration.GetRequiredSection(FeaturesConfiguration.CONFIG_NAME);
        services.Configure<FeaturesConfiguration>(featuresSection);
        var featuresConfiguration = configuration.Get<FeaturesConfiguration>() ?? new FeaturesConfiguration();
        services.AddSingleton<IFeatureProvider>(new FeatureProvider(featuresConfiguration));*/

        services.AddScoped<ICatalogViewModelService, CachedCatalogViewModelService>();

        return services;
    }
}
