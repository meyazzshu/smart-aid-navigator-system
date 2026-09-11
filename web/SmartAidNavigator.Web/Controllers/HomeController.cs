using System.Diagnostics;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Models;

namespace SmartAidNavigator.Web.Controllers
{
    public class HomeController : Controller
    {
        private readonly ILogger<HomeController> _logger;
        private readonly AppDbContext _db;
        private readonly IConfiguration _configuration;

        public HomeController(
            ILogger<HomeController> logger,
            AppDbContext db,
            IConfiguration configuration)
        {
            _logger = logger;
            _db = db;
            _configuration = configuration;
        }

        public async Task<IActionResult> Index()
        {
            var shelters = await _db.Shelters
                .Where(s => s.IsActive == true
                    && s.Latitude != null
                    && s.Longitude != null)
                .OrderBy(s => s.ShelterName)
                .Select(s => new
                {
                    id = s.ShelterId,
                    type = "SHELTER",
                    name = s.ShelterName,
                    address = s.AddressLine,
                    city = s.City,
                    state = s.State,
                    postalCode = s.PostalCode,
                    latitude = s.Latitude,
                    longitude = s.Longitude,
                    capacity = s.Capacity,
                    currentOccupancy = s.CurrentOccupancy
                })
                .ToListAsync();

            var ngos = await _db.Ngos
                .Where(n => n.IsActive == true
                    && n.Latitude != null
                    && n.Longitude != null)
                .OrderBy(n => n.NgoName)
                .Select(n => new
                {
                    id = n.NgoId,
                    type = "NGO",
                    name = n.NgoName,
                    address = n.AddressLine,
                    city = n.City,
                    state = n.State,
                    postalCode = n.PostalCode,
                    latitude = n.Latitude,
                    longitude = n.Longitude,
                    capacity = (int?)null,
                    currentOccupancy = (int?)null
                })
                .ToListAsync();

            var mapLocations = shelters.Cast<object>()
                .Concat(ngos.Cast<object>())
                .ToList();

            ViewBag.MapLocationsJson = JsonSerializer.Serialize(mapLocations);

            ViewBag.HomeNgoCount = await _db.Ngos.CountAsync(n => n.IsActive == true);
            ViewBag.HomeShelterCount = await _db.Shelters.CountAsync(s => s.IsActive == true);
            ViewBag.HomeDeliveryCount = await _db.Deliveries.CountAsync();
            ViewBag.HomeBeneficiaryCount = await _db.Beneficiaries.CountAsync();

            ViewBag.GoogleMapsApiKey = _configuration["GoogleMaps:ApiKey"]
                ?? Environment.GetEnvironmentVariable("GOOGLE_MAPS_API_KEY");

            return View();
        }

        public IActionResult Privacy()
        {
            return View();
        }

        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }
    }
}