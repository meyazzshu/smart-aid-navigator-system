
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.Models;
using SmartAidNavigator.Web.ViewModels;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("SHELTER_MANAGER")]
public class BeneficiaryNeedsController : Controller
{
    private readonly AppDbContext _db;
    public BeneficiaryNeedsController(AppDbContext db) => _db = db;

    // Show all needs for all beneficiaries in a shelter
    public async Task<IActionResult> Index(string? search, string? priority, string? status, string? sortBy)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var shelter = await _db.Shelters.FirstOrDefaultAsync(s => s.ShelterId == shelterId);
        if (shelter == null) return NotFound();

        search = string.IsNullOrWhiteSpace(search) ? null : search.Trim();
        priority = string.IsNullOrWhiteSpace(priority) ? null : priority.Trim().ToUpper();
        status = string.IsNullOrWhiteSpace(status) ? null : status.Trim().ToUpper();
        sortBy = string.IsNullOrWhiteSpace(sortBy) ? "newest" : sortBy.Trim().ToLower();

        var allRows = await _db.BeneficiaryNeeds
            .Include(n => n.Beneficiary)
                .ThenInclude(b => b!.Person)
            .Include(n => n.Item)
            .Where(n => n.Beneficiary != null && n.Beneficiary.ShelterId == shelterId)
            .ToListAsync();

        var rows = allRows.AsEnumerable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            rows = rows.Where(x =>
                (x.Beneficiary?.Person?.FullName ?? "").Contains(search, StringComparison.OrdinalIgnoreCase) ||
                (x.Item?.ItemName ?? "").Contains(search, StringComparison.OrdinalIgnoreCase) ||
                (x.Notes ?? "").Contains(search, StringComparison.OrdinalIgnoreCase));
        }

        if (!string.IsNullOrWhiteSpace(priority))
        {
            rows = rows.Where(x => x.Priority == priority);
        }

        if (!string.IsNullOrWhiteSpace(status))
        {
            rows = rows.Where(x => x.RequestStatus == status);
        }

        rows = sortBy switch
        {
            "critical" => rows.OrderByDescending(x => x.Priority == "CRITICAL"),
            "high-critical" => rows.OrderByDescending(x => x.Priority == "CRITICAL" || x.Priority == "HIGH"),
            "medium" => rows.OrderByDescending(x => x.Priority == "MEDIUM"),
            "low" => rows.OrderByDescending(x => x.Priority == "LOW"),
            "qty-high" => rows.OrderByDescending(x => x.RequiredQuantity),
            "qty-low" => rows.OrderBy(x => x.RequiredQuantity),
            "oldest" => rows.OrderBy(x => x.CreatedAt),
            "beneficiary-az" => rows.OrderBy(x => x.Beneficiary?.Person?.FullName),
            "item-az" => rows.OrderBy(x => x.Item?.ItemName),
            _ => rows.OrderByDescending(x => x.CreatedAt)
        };

        var vm = new BeneficiaryNeedIndexVm
        {
            ShelterName = shelter.ShelterName,
            Search = search,
            Priority = priority,
            SortBy = sortBy,

            TotalCount = allRows.Count,
            HighCriticalCount = allRows.Count(x => x.Priority == "HIGH" || x.Priority == "CRITICAL"),
            MediumCount = allRows.Count(x => x.Priority == "MEDIUM"),
            LowCount = allRows.Count(x => x.Priority == "LOW"),

            Rows = rows.ToList(),

            Status = status,

            SubmittedCount = allRows.Count(x => x.RequestStatus == "SUBMITTED"),
            ReviewCount = allRows.Count(x => x.RequestStatus == "UNDER_REVIEW"),
            AwaitingDonationCount = allRows.Count(x => x.RequestStatus == "AWAITING_DONATION"),
            ReadyForPickupCount = allRows.Count(x => x.RequestStatus == "READY_FOR_PICKUP"),
            FulfilledCount = allRows.Count(x => x.RequestStatus == "FULFILLED"),

        };

        return View(vm);
    }

    // Show all needs for a specific beneficiary (existing logic)
    public async Task<IActionResult> IndividualNeeds(long beneficiaryId)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var b = await _db.Beneficiaries
            .Include(x => x.Person)
            .FirstOrDefaultAsync(x => x.BeneficiaryId == beneficiaryId && x.ShelterId == shelterId);
        if (b == null) return NotFound();

        ViewBag.Beneficiary = b;

        var needs = await _db.BeneficiaryNeeds
            .Include(n => n.Item)
            .Where(n => n.BeneficiaryId == beneficiaryId)
            .OrderByDescending(n => n.CreatedAt)
            .ToListAsync();

        return View(needs);
    }

    [HttpGet]
    public async Task<IActionResult> Create(long beneficiaryId)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var b = await _db.Beneficiaries
            .Include(x => x.Person)
            .FirstOrDefaultAsync(x => x.BeneficiaryId == beneficiaryId && x.ShelterId == shelterId);
        if (b == null) return NotFound();

        ViewBag.Beneficiary = b;
        ViewBag.Items = await _db.AidItems.Where(x => x.IsActive).OrderBy(x => x.ItemName).ToListAsync();

        return View(new BeneficiaryNeed { BeneficiaryId = beneficiaryId, Priority = "MEDIUM", RequiredQuantity = 1 });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(BeneficiaryNeed need)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var b = await _db.Beneficiaries
            .Include(x => x.Person)
            .FirstOrDefaultAsync(x => x.BeneficiaryId == need.BeneficiaryId && x.ShelterId == shelterId);
        if (b == null) return NotFound();

        if (!ModelState.IsValid)
        {
            ViewBag.Beneficiary = b;
            ViewBag.Items = await _db.AidItems.Where(x => x.IsActive).OrderBy(x => x.ItemName).ToListAsync();
            return View(need);
        }

        var inventory = await _db.ShelterInventory
            .FirstOrDefaultAsync(x =>
                x.ShelterId == shelterId &&
                x.ItemId == need.ItemId);

        need.RequestStatus = inventory != null && inventory.Quantity >= need.RequiredQuantity
            ? "READY_FOR_PICKUP"
            : "AWAITING_DONATION";

        need.ReviewedByUserId = CurrentUserHelper.GetUserId(HttpContext);
        need.ReviewedAt = DateTime.UtcNow;
        need.CreatedAt = DateTime.Now;

        _db.BeneficiaryNeeds.Add(need);
        await _db.SaveChangesAsync();

        return RedirectToAction(nameof(IndividualNeeds), new { beneficiaryId = need.BeneficiaryId });
    }

    public async Task<IActionResult> Details(long id)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var need = await _db.BeneficiaryNeeds
            .Include(x => x.Beneficiary)
                .ThenInclude(b => b!.Person)
            .Include(x => x.Item)
                .ThenInclude(i => i!.Category)
            .FirstOrDefaultAsync(x =>
                x.NeedId == id &&
                x.Beneficiary != null &&
                x.Beneficiary.ShelterId == shelterId);

        if (need == null) return NotFound();

        return View(need);
    }

    [HttpGet]
    public async Task<IActionResult> Edit(long id)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var need = await _db.BeneficiaryNeeds
            .Include(x => x.Beneficiary)
                .ThenInclude(b => b!.Person)
            .FirstOrDefaultAsync(x =>
                x.NeedId == id &&
                x.Beneficiary != null &&
                x.Beneficiary.ShelterId == shelterId);

        if (need == null) return NotFound();

        ViewBag.Beneficiary = need.Beneficiary;
        ViewBag.Items = await _db.AidItems
            .Where(x => x.IsActive)
            .OrderBy(x => x.ItemName)
            .ToListAsync();

        return View(need);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(long id, BeneficiaryNeed vm)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        if (id != vm.NeedId) return BadRequest();

        var need = await _db.BeneficiaryNeeds
            .Include(x => x.Beneficiary)
                .ThenInclude(b => b!.Person)
            .FirstOrDefaultAsync(x =>
                x.NeedId == id &&
                x.Beneficiary != null &&
                x.Beneficiary.ShelterId == shelterId);

        if (need == null) return NotFound();

        var allowedPriority = new[] { "LOW", "MEDIUM", "HIGH", "CRITICAL" };
        vm.Priority = string.IsNullOrWhiteSpace(vm.Priority) ? "MEDIUM" : vm.Priority.Trim().ToUpper();

        if (!allowedPriority.Contains(vm.Priority))
            ModelState.AddModelError(nameof(vm.Priority), "Invalid priority.");

        if (!await _db.AidItems.AnyAsync(x => x.ItemId == vm.ItemId && x.IsActive))
            ModelState.AddModelError(nameof(vm.ItemId), "Invalid aid item.");

        if (vm.RequiredQuantity <= 0)
            ModelState.AddModelError(nameof(vm.RequiredQuantity), "Required quantity must be at least 1.");

        if (!ModelState.IsValid)
        {
            ViewBag.Beneficiary = need.Beneficiary;
            ViewBag.Items = await _db.AidItems
                .Where(x => x.IsActive)
                .OrderBy(x => x.ItemName)
                .ToListAsync();

            return View(vm);
        }

        need.ItemId = vm.ItemId;
        need.RequiredQuantity = vm.RequiredQuantity;
        need.Priority = vm.Priority;
        need.Notes = string.IsNullOrWhiteSpace(vm.Notes) ? null : vm.Notes.Trim();

        await _db.SaveChangesAsync();

        return RedirectToAction(nameof(Details), new { id = need.NeedId });
    }

    [HttpGet]
    public async Task<IActionResult> Delete(long id)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var need = await _db.BeneficiaryNeeds
            .Include(x => x.Beneficiary)
                .ThenInclude(b => b!.Person)
            .Include(x => x.Item)
            .FirstOrDefaultAsync(x =>
                x.NeedId == id &&
                x.Beneficiary != null &&
                x.Beneficiary.ShelterId == shelterId);

        if (need == null) return NotFound();

        return View(need);
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(long id)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var need = await _db.BeneficiaryNeeds
            .Include(x => x.Beneficiary)
            .FirstOrDefaultAsync(x =>
                x.NeedId == id &&
                x.Beneficiary != null &&
                x.Beneficiary.ShelterId == shelterId);

        if (need == null) return NotFound();

        _db.BeneficiaryNeeds.Remove(need);
        await _db.SaveChangesAsync();

        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Review(long id)
    {
        var need = await GetNeedForCurrentShelterAsync(id);
        if (need == null) return NotFound();

        need.RequestStatus = "UNDER_REVIEW";

        await _db.SaveChangesAsync();
        TempData["Success"] = "Request moved to Under Review.";

        return RedirectToAction(nameof(Details), new { id });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Approve(long id)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);
        var userId = CurrentUserHelper.GetUserId(HttpContext);

        var need = await GetNeedForCurrentShelterAsync(id);
        if (need == null) return NotFound();

        var inventory = await _db.ShelterInventory
            .FirstOrDefaultAsync(x => x.ShelterId == shelterId && x.ItemId == need.ItemId);

        need.RequestStatus = inventory != null && inventory.Quantity >= need.RequiredQuantity
            ? "READY_FOR_PICKUP"
            : "AWAITING_DONATION";

        need.ReviewedByUserId = userId;
        need.ReviewedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        TempData["Success"] = "Request approved and stock availability checked.";

        return RedirectToAction(nameof(Details), new { id });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Reject(long id, string? rejectionReason)
    {
        var userId = CurrentUserHelper.GetUserId(HttpContext);

        var need = await GetNeedForCurrentShelterAsync(id);
        if (need == null) return NotFound();

        need.RequestStatus = "REJECTED";
        need.RejectionReason = string.IsNullOrWhiteSpace(rejectionReason)
            ? null
            : rejectionReason.Trim();
        need.ReviewedByUserId = userId;
        need.ReviewedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        TempData["Success"] = "Request rejected.";

        return RedirectToAction(nameof(Details), new { id });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> RefreshAvailability(long id)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var need = await GetNeedForCurrentShelterAsync(id);
        if (need == null) return NotFound();

        var inventory = await _db.ShelterInventory
            .FirstOrDefaultAsync(x => x.ShelterId == shelterId && x.ItemId == need.ItemId);

        if (inventory != null && inventory.Quantity >= need.RequiredQuantity)
        {
            need.RequestStatus = "READY_FOR_PICKUP";
            TempData["Success"] = "Stock is now available. Request is ready for pickup.";
        }
        else
        {
            TempData["Error"] = "Stock is still not enough.";
        }

        await _db.SaveChangesAsync();

        return RedirectToAction(nameof(Details), new { id });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Fulfill(long id)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);
        var userId = CurrentUserHelper.GetUserId(HttpContext);

        var need = await GetNeedForCurrentShelterAsync(id);
        if (need == null) return NotFound();

        var inventory = await _db.ShelterInventory
            .FirstOrDefaultAsync(x => x.ShelterId == shelterId && x.ItemId == need.ItemId);

        if (inventory == null || inventory.Quantity < need.RequiredQuantity)
        {
            TempData["Error"] = "Not enough shelter inventory to fulfill this request.";
            return RedirectToAction(nameof(Details), new { id });
        }

        inventory.Quantity -= need.RequiredQuantity;
        inventory.UpdatedAt = DateTime.UtcNow;

        _db.InventoryTransactions.Add(new InventoryTransaction
        {
            OwnerType = "SHELTER",
            OwnerId = shelterId,
            ItemId = need.ItemId,
            TransactionType = "OUT",
            Quantity = need.RequiredQuantity,
            SourceType = "BENEFICIARY_DISTRIBUTION",
            SourceId = need.NeedId,
            Note = $"Aid distributed for beneficiary need #{need.NeedId}",
            CreatedBy = userId,
            CreatedAt = DateTime.UtcNow
        });

        need.RequestStatus = "FULFILLED";
        need.FulfilledByUserId = userId;
        need.FulfilledAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        TempData["Success"] = "Aid request fulfilled and inventory deducted.";

        return RedirectToAction(nameof(Details), new { id });
    }

    private async Task<BeneficiaryNeed?> GetNeedForCurrentShelterAsync(long id)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        return await _db.BeneficiaryNeeds
            .Include(x => x.Beneficiary)
                .ThenInclude(b => b!.Person)
            .Include(x => x.Item)
                .ThenInclude(i => i!.Category)
            .FirstOrDefaultAsync(x =>
                x.NeedId == id &&
                x.Beneficiary != null &&
                x.Beneficiary.ShelterId == shelterId);
    }


}
