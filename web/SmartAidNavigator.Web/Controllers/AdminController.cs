using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Models;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("ADMIN")]
public class AdminController : Controller
{
    private readonly AppDbContext _db;
    public AdminController(AppDbContext db) => _db = db;

    public async Task<IActionResult> Dashboard()
    {
        ViewBag.NgoCount = await _db.Ngos.CountAsync(x => x.IsActive);
        ViewBag.ShelterCount = await _db.Shelters.CountAsync(x => x.IsActive);
        ViewBag.UserCount = await _db.Users.CountAsync(x => x.IsActive);
        ViewBag.DeliveryCount = await _db.Deliveries.CountAsync();
        ViewBag.BeneficiaryCount = await _db.Beneficiaries.CountAsync();
        ViewBag.AidItemCount = await _db.AidItems.CountAsync(x => x.IsActive);

        // Status breakdown for deliveries
        ViewBag.DeliveryPlanned = await _db.Deliveries.CountAsync(x => x.Status == DeliveryStatus.PLANNED);
        ViewBag.DeliveryRouted = await _db.Deliveries.CountAsync(x => x.Status == DeliveryStatus.ROUTED);
        ViewBag.DeliveryInTransit = await _db.Deliveries.CountAsync(x => x.Status == DeliveryStatus.IN_TRANSIT);
        ViewBag.DeliveryDelivered = await _db.Deliveries.CountAsync(x => x.Status == DeliveryStatus.DELIVERED);
        ViewBag.DeliveryCancelled = await _db.Deliveries.CountAsync(x => x.Status == DeliveryStatus.CANCELLED);

        // Recent NGOs
        ViewBag.RecentNgos = await _db.Ngos.OrderByDescending(x => x.CreatedAt).Take(5).ToListAsync();

        // Recent Shelters
        ViewBag.RecentShelters = await _db.Shelters
            .Include(x => x.Ngo)
            .OrderByDescending(x => x.CreatedAt).Take(5).ToListAsync();

        return View();
    }
}
