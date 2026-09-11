using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.Models;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("NGO_STAFF")]
public class NgoStaffController : Controller
{
    private readonly AppDbContext _db;
    public NgoStaffController(AppDbContext db) => _db = db;

    public async Task<IActionResult> Dashboard()
    {
        var userIdStr = HttpContext.Session.GetString(SessionKeys.UserId);
        if (string.IsNullOrEmpty(userIdStr)) return RedirectToAction("Login", "Account");
        var userId = long.Parse(userIdStr);

        var ngoStaff = await _db.NgoStaff.FirstOrDefaultAsync(x => x.UserId == userId);
        if (ngoStaff == null)
            return RedirectToAction("Create", "NgoOnboarding");

        var ngoId = ngoStaff.NgoId;

        var ngo = await _db.Ngos.FirstOrDefaultAsync(x => x.NgoId == ngoId);
        ViewBag.NgoName = ngo?.NgoName ?? "Your NGO";

        ViewBag.ShelterCount = await _db.Shelters.CountAsync(x => x.NgoId == ngoId && x.IsActive);
        ViewBag.TotalDeliveries = await _db.Deliveries.CountAsync(x => x.NgoId == ngoId);
        ViewBag.ActiveDeliveries = await _db.Deliveries.CountAsync(x => x.NgoId == ngoId
            && (x.Status == DeliveryStatus.PLANNED || x.Status == DeliveryStatus.ROUTED || x.Status == DeliveryStatus.IN_TRANSIT));
        ViewBag.CompletedDeliveries = await _db.Deliveries.CountAsync(x => x.NgoId == ngoId && x.Status == DeliveryStatus.DELIVERED);
        ViewBag.RouteCount = await _db.Routes.CountAsync(x => x.NgoId == ngoId);

        // Delivery status breakdown
        ViewBag.DeliveryPlanned = await _db.Deliveries.CountAsync(x => x.NgoId == ngoId && x.Status == DeliveryStatus.PLANNED);
        ViewBag.DeliveryRouted = await _db.Deliveries.CountAsync(x => x.NgoId == ngoId && x.Status == DeliveryStatus.ROUTED);
        ViewBag.DeliveryInTransit = await _db.Deliveries.CountAsync(x => x.NgoId == ngoId && x.Status == DeliveryStatus.IN_TRANSIT);
        ViewBag.DeliveryDelivered = await _db.Deliveries.CountAsync(x => x.NgoId == ngoId && x.Status == DeliveryStatus.DELIVERED);
        ViewBag.DeliveryCancelled = await _db.Deliveries.CountAsync(x => x.NgoId == ngoId && x.Status == DeliveryStatus.CANCELLED);

        // Recent deliveries
        ViewBag.RecentDeliveries = await _db.Deliveries
            .Where(x => x.NgoId == ngoId)
            .Include(x => x.Shelter)
            .OrderByDescending(x => x.CreatedAt)
            .Take(5)
            .ToListAsync();

        // Recent routes
        ViewBag.RecentRoutes = await _db.Routes
            .Where(x => x.NgoId == ngoId)
            .OrderByDescending(x => x.CreatedAt)
            .Take(5)
            .ToListAsync();

        ViewBag.PendingDonations = await _db.Donations.CountAsync(x => x.NgoId == ngoId && x.Status == "PENDING");
        ViewBag.ConfirmedDonations = await _db.Donations.CountAsync(x => x.NgoId == ngoId && x.Status == "CONFIRMED");
        ViewBag.CompletedDonations = await _db.Donations.CountAsync(x => x.NgoId == ngoId && x.Status == "COMPLETED");

        ViewBag.RecentDonations = await _db.Donations
            .Where(x => x.NgoId == ngoId)
            .Include(x => x.Donor)
            .OrderByDescending(x => x.CreatedAt)
            .Take(5)
            .ToListAsync();

        ViewBag.NgoInventoryItems = await _db.NgoInventory.CountAsync(x => x.NgoId == ngoId);
        ViewBag.NgoLowStockItems = await _db.NgoInventory
            .CountAsync(x => x.NgoId == ngoId && x.MinimumLevel > 0 && x.Quantity < x.MinimumLevel);

        var linkedShelterIds = await _db.Shelters
            .Where(x => x.NgoId == ngoId && x.IsActive)
            .Select(x => x.ShelterId)
            .ToListAsync();

        ViewBag.AwaitingBeneficiaryNeeds = await _db.BeneficiaryNeeds
            .Include(x => x.Beneficiary)
            .CountAsync(x =>
                x.Beneficiary != null &&
                linkedShelterIds.Contains(x.Beneficiary.ShelterId) &&
                x.RequestStatus == "AWAITING_DONATION");

        return View();
    }
}
