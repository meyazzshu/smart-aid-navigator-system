using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.Models;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("SHELTER_MANAGER")]
public class MyShelterController : Controller
{
    private readonly AppDbContext _db;
    public MyShelterController(AppDbContext db) => _db = db;

    private long GetUserId()
    {
        var s = HttpContext.Session.GetString(SessionKeys.UserId);
        if (string.IsNullOrEmpty(s)) throw new InvalidOperationException("Not logged in.");
        return long.Parse(s);
    }

    private async Task<long?> GetMyShelterIdAsync(long userId)
    {
        return await _db.ShelterManagers
            .Where(x => x.UserId == userId)
            .Select(x => (long?)x.ShelterId)
            .FirstOrDefaultAsync();
    }

    [HttpGet]
    public async Task<IActionResult> Details()
    {
        var userId = GetUserId();
        var shelterId = await GetMyShelterIdAsync(userId);
        if (shelterId == null) return RedirectToAction("Create", "ShelterOnboarding");

        var shelter = await _db.Shelters
            .Include(s => s.Ngo)
            .FirstOrDefaultAsync(s => s.ShelterId == shelterId.Value);

        if (shelter == null) return RedirectToAction("Create", "ShelterOnboarding");


        var inventory = await _db.ShelterInventory
            .Include(i => i.Item)
            .ThenInclude(item => item.Category)
            .Where(i => i.ShelterId == shelterId.Value)
            .ToListAsync();
        ViewBag.InventoryLabels = inventory.Select(i => i.Item?.ItemName ?? "Unknown").ToArray();
        ViewBag.InventoryData = inventory.Select(i => i.Quantity).ToArray();

        // Inventory breakdown by type/category
        var inventoryByType = inventory
            .Where(i => i.Item?.Category != null)
            .GroupBy(i => i.Item.Category.CategoryName)
            .Select(g => new {
                Category = g.Key,
                Total = g.Sum(i => i.Quantity)
            })
            .ToList();

        ViewBag.InventoryTypeLabels = inventoryByType.Select(x => x.Category).ToArray();
        ViewBag.InventoryTypeData = inventoryByType.Select(x => x.Total).ToArray();


        // Deliveries breakdown by status
        var deliveries = await _db.Deliveries
            .Where(d => d.ShelterId == shelterId.Value)
            .ToListAsync();
        ViewBag.DeliveryStatusLabels = deliveries.GroupBy(d => d.Status.ToString()).Select(g => g.Key).ToArray();
        ViewBag.DeliveryStatusData = deliveries.GroupBy(d => d.Status.ToString()).Select(g => g.Count()).ToArray();

        // Beneficiary needs breakdown by item
        var beneficiaries = await _db.Beneficiaries
            .Include(b => b.Person)
            .Where(b => b.ShelterId == shelterId.Value)
            .ToListAsync();
        var needs = await _db.BeneficiaryNeeds
            .Include(n => n.Item)
            .Where(n => beneficiaries.Select(b => b.BeneficiaryId).Contains(n.BeneficiaryId))
            .ToListAsync();
        ViewBag.NeedsLabels = needs.Select(n => n.Item?.ItemName ?? "Unknown").ToArray();
        ViewBag.NeedsData = needs.Select(n => n.RequiredQuantity).ToArray();

        // Define age groups
        var ageGroups = new[] { "Baby", "Child", "Teenage", "Adult", "Senior" };
        int GetAgeGroup(int? age)
        {
            if (age == null) return 3; // Default to "Adult" if age is missing
            if (age < 3) return 0; // Baby
            if (age < 13) return 1; // Child
            if (age < 20) return 2; // Teenage
            if (age < 60) return 3; // Adult
            return 4; // Senior
        }

        // Initialize counts
        var maleCounts = new int[ageGroups.Length];
        var femaleCounts = new int[ageGroups.Length];

        foreach (var b in beneficiaries)
        {
            var personAge = PersonHelper.CalculateAge(b.Person?.DateOfBirth);
            var groupIdx = GetAgeGroup(personAge);
            var gender = (b.Person?.Gender ?? "").Trim().ToLower();
            if (gender == "male" || gender == "m")
                maleCounts[groupIdx]++;
            else if (gender == "female" || gender == "f")
                femaleCounts[groupIdx]++;
            // else ignore or handle as needed
        }

        // ---- Utilize sources chart-------

        // Top 5 most needed items
        var topNeeds = needs
            .Where(n => n.Item != null)
            .GroupBy(n => n.Item.ItemName)
            .Select(g => new { Item = g.Key, Total = g.Sum(n => n.RequiredQuantity) })
            .OrderByDescending(x => x.Total)
            .Take(5)
            .ToList();

        ViewBag.TopNeedsLabels = topNeeds.Select(x => x.Item).ToArray();
        ViewBag.TopNeedsData = topNeeds.Select(x => x.Total).ToArray();

        // Stock vs Needs for each item
        var stockVsNeeds = inventory
            .Where(i => i.Item != null)
            .GroupJoin(
                needs.Where(n => n.Item != null),
                inv => inv.Item.ItemId,
                need => need.Item.ItemId,
                (inv, needGroup) => new {
                    Item = inv.Item.ItemName,
                    Stock = inv.Quantity,
                    Needs = needGroup.Sum(n => n.RequiredQuantity)
                })
            .OrderByDescending(x => x.Needs)
            .Take(5)
            .ToList();

        ViewBag.StockVsNeedsLabels = stockVsNeeds.Select(x => x.Item).ToArray();
        ViewBag.StockVsNeedsStock = stockVsNeeds.Select(x => x.Stock).ToArray();
        ViewBag.StockVsNeedsNeeds = stockVsNeeds.Select(x => x.Needs).ToArray();

        // deliveries over time
        var deliveries2 = _db.Deliveries
            .Where(d => d.ShelterId == shelterId)
            .ToList();

        var deliveriesByMonth = deliveries2
            .GroupBy(d => d.CreatedAt.ToString("yyyy-MM"))
            .Select(g => new { Month = g.Key, Count = g.Count() })
            .OrderBy(x => x.Month)
            .ToList();

        ViewBag.DeliveriesMonthLabels = deliveriesByMonth.Select(x => x.Month).ToArray();
        ViewBag.DeliveriesMonthData = deliveriesByMonth.Select(x => x.Count).ToArray();


        // --- End analytics code ---


        ViewBag.TotalInventory = inventory.Sum(i => i.Quantity);
        ViewBag.InventoryTypes = inventory.Count;
        ViewBag.OutstandingDeliveries = deliveries.Count(d => d.Status != DeliveryStatus.DELIVERED && d.Status != DeliveryStatus.CANCELLED);
        ViewBag.TotalBeneficiaries = beneficiaries.Count;
        ViewBag.TotalNeeds = needs.Sum(n => n.RequiredQuantity);
        ViewBag.BeneficiaryAgeGroups = ageGroups;
        ViewBag.BeneficiaryMaleCounts = maleCounts;
        ViewBag.BeneficiaryFemaleCounts = femaleCounts;

        return View(shelter);
    }

    [HttpGet]
    public async Task<IActionResult> Edit()
    {
        var userId = GetUserId();
        var shelterId = await GetMyShelterIdAsync(userId);
        if (shelterId == null) return RedirectToAction("Create", "ShelterOnboarding");

        var shelter = await _db.Shelters.FirstOrDefaultAsync(s => s.ShelterId == shelterId.Value);
        if (shelter == null) return RedirectToAction("Create", "ShelterOnboarding");

        return View(shelter);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(Shelter shelter)
    {
        var userId = GetUserId();
        var shelterId = await GetMyShelterIdAsync(userId);
        if (shelterId == null) return Forbid();

        // prevent editing other shelter
        if (shelter.ShelterId != shelterId.Value) return Forbid();

        if (!ModelState.IsValid) return View(shelter);

        _db.Entry(shelter).State = EntityState.Modified;
        await _db.SaveChangesAsync();

        return RedirectToAction(nameof(Details));
    }

}
