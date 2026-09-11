using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.Models;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("SHELTER_MANAGER")]
public class ShelterManagerController : Controller
{
    private readonly AppDbContext _db;
    public ShelterManagerController(AppDbContext db) => _db = db;

    public async Task<IActionResult> Dashboard()
    {
        var userIdStr = HttpContext.Session.GetString(SessionKeys.UserId);
        if (string.IsNullOrEmpty(userIdStr)) return RedirectToAction("Login", "Account");
        var userId = long.Parse(userIdStr);

        var shelterMgr = await _db.ShelterManagers.FirstOrDefaultAsync(x => x.UserId == userId);
        if (shelterMgr == null)
            return RedirectToAction("Create", "ShelterOnboarding");

        var shelterId = shelterMgr.ShelterId;
        var shelter = await _db.Shelters.Include(x => x.Ngo).FirstOrDefaultAsync(x => x.ShelterId == shelterId);

        ViewBag.ShelterName = shelter?.ShelterName ?? "Your Shelter";
        ViewBag.NgoName = shelter?.Ngo?.NgoName ?? "-";

        ViewBag.BeneficiaryCount = await _db.Beneficiaries.CountAsync(x => x.ShelterId == shelterId);
        ViewBag.NeedCount = await _db.BeneficiaryNeeds.CountAsync(x => x.Beneficiary!.ShelterId == shelterId);

        var inventoryRows = await _db.ShelterInventory.Where(x => x.ShelterId == shelterId).ToListAsync();
        ViewBag.TotalInventoryItems = inventoryRows.Count;
        ViewBag.LowStockItems = inventoryRows.Count(x => x.MinimumLevel > 0 && x.Quantity < x.MinimumLevel);

        ViewBag.IncomingDeliveries = await _db.Deliveries
            .CountAsync(x => x.ShelterId == shelterId
                && (x.Status == DeliveryStatus.PLANNED || x.Status == DeliveryStatus.ROUTED || x.Status == DeliveryStatus.IN_TRANSIT));

        // Recent beneficiaries
        ViewBag.RecentBeneficiaries = await _db.Beneficiaries
            .Include(x => x.Person)
            .Where(x => x.ShelterId == shelterId)
            .OrderByDescending(x => x.CreatedAt)
            .Take(5)
            .ToListAsync();

        // Low stock items
        ViewBag.LowStockList = await (from item in _db.AidItems
                                      join cat in _db.AidCategories on item.CategoryId equals cat.CategoryId
                                      join inv in _db.ShelterInventory.Where(x => x.ShelterId == shelterId)
                                          on item.ItemId equals inv.ItemId
                                      where inv.MinimumLevel > 0 && inv.Quantity < inv.MinimumLevel
                                      orderby inv.Quantity ascending
                                      select new
                                      {
                                          item.ItemId,
                                          item.ItemName,
                                          cat.CategoryName,
                                          item.Unit,
                                          inv.Quantity,
                                          inv.MinimumLevel
                                      })
                                    .Take(5)
                                    .ToListAsync();

        // Recent needs
        ViewBag.RecentNeeds = await _db.BeneficiaryNeeds
            .Where(x => x.Beneficiary!.ShelterId == shelterId)
            .Include(x => x.Beneficiary)
            .ThenInclude(b => b!.Person)
            .Include(x => x.Item)
            .OrderByDescending(x => x.CreatedAt)
            .Take(5)
            .ToListAsync();

        ViewBag.PendingShelterRequests = await _db.ShelterRequests
            .CountAsync(x =>
                x.ShelterId == shelterId &&
                x.Status == "PENDING");

        return View();
    }
}
