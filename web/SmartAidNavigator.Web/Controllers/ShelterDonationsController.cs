using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.Models;
using SmartAidNavigator.Web.ViewModels;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("SHELTER_MANAGER")]
public class ShelterDonationsController : Controller
{
    private readonly AppDbContext _db;

    public ShelterDonationsController(AppDbContext db)
    {
        _db = db;
    }

    public async Task<IActionResult> Index(string? status, string? type)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var shelter = await _db.Shelters
            .Include(x => x.Ngo)
            .FirstOrDefaultAsync(x => x.ShelterId == shelterId);

        if (shelter == null) return NotFound();

        var ngoId = shelter.NgoId;

        var query = _db.Donations
            .Include(x => x.Donor).ThenInclude(d => d!.Person)
            .Include(x => x.Payment)
            .Include(x => x.DonationItems)
                .ThenInclude(x => x.Item)
            .Where(x => x.NgoId == ngoId)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(status))
        {
            query = query.Where(x => x.Status == status);
        }

        if (!string.IsNullOrWhiteSpace(type))
        {
            query = query.Where(x => x.DonationType == type);
        }

        var allForStats = await _db.Donations
            .Where(x => x.NgoId == ngoId)
            .ToListAsync();

        var donations = await query
            .OrderByDescending(x => x.CreatedAt)
            .ToListAsync();

        var vm = new ShelterDonationIndexVm
        {
            ShelterName = shelter.ShelterName,
            Status = status,
            Type = type,
            Donations = donations,
            PendingCount = allForStats.Count(x => x.Status == "PENDING"),
            ConfirmedCount = allForStats.Count(x => x.Status == "CONFIRMED"),
            CompletedCount = allForStats.Count(x => x.Status == "COMPLETED"),
            CancelledCount = allForStats.Count(x => x.Status == "CANCELLED")
        };

        return View(vm);
    }

    public async Task<IActionResult> Details(long id)
    {
        var donation = await GetDonationForCurrentShelterAsync(id);
        if (donation == null) return NotFound();

        return View(new ShelterDonationDetailVm
        {
            Donation = donation
        });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Confirm(long id)
    {
        var donation = await GetDonationForCurrentShelterAsync(id);
        if (donation == null) return NotFound();

        if (donation.Status == "CANCELLED" || donation.Status == "COMPLETED")
        {
            TempData["Error"] = "This donation cannot be confirmed.";
            return RedirectToAction(nameof(Details), new { id });
        }

        donation.Status = "CONFIRMED";

        await _db.SaveChangesAsync();

        TempData["Success"] = "Donation confirmed successfully.";
        return RedirectToAction(nameof(Details), new { id });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Complete(long id)
    {
        var donation = await GetDonationForCurrentShelterAsync(id);
        if (donation == null) return NotFound();

        if (donation.Status == "CANCELLED")
        {
            TempData["Error"] = "Cancelled donation cannot be completed.";
            return RedirectToAction(nameof(Details), new { id });
        }

        if (donation.Status == "COMPLETED")
        {
            TempData["Error"] = "Donation is already completed.";
            return RedirectToAction(nameof(Details), new { id });
        }

        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);
        var userId = CurrentUserHelper.GetUserId(HttpContext);

        using var tx = await _db.Database.BeginTransactionAsync();

        try
        {
            if (donation.DonationType == "ITEM")
            {
                if (donation.DonationItems == null || !donation.DonationItems.Any())
                {
                    TempData["Error"] = "This item donation has no items.";
                    return RedirectToAction(nameof(Details), new { id });
                }

                foreach (var item in donation.DonationItems)
                {
                    var inventory = await _db.ShelterInventory
                        .FirstOrDefaultAsync(x => x.ShelterId == shelterId && x.ItemId == item.ItemId);

                    if (inventory == null)
                    {
                        inventory = new ShelterInventory
                        {
                            ShelterId = shelterId,
                            ItemId = item.ItemId,
                            Quantity = 0,
                            MinimumLevel = 0,
                            UpdatedAt = DateTime.UtcNow
                        };

                        _db.ShelterInventory.Add(inventory);
                    }

                    inventory.Quantity += item.Quantity;
                    inventory.UpdatedAt = DateTime.UtcNow;

                    _db.InventoryTransactions.Add(new InventoryTransaction
                    {
                        OwnerType = "SHELTER",
                        OwnerId = shelterId,
                        ItemId = item.ItemId,
                        TransactionType = "IN",
                        Quantity = item.Quantity,
                        SourceType = "DONATION",
                        SourceId = donation.DonationId,
                        Note = $"Received from donation #{donation.DonationId}",
                        CreatedBy = userId,
                        CreatedAt = DateTime.UtcNow
                    });

                    await RefreshAwaitingDonationNeedsAsync(shelterId, item.ItemId);
                }
            }

            donation.Status = "COMPLETED";

            await _db.SaveChangesAsync();
            await tx.CommitAsync();

            TempData["Success"] = "Donation completed successfully. Item donation has been added to shelter inventory and transaction history.";
            return RedirectToAction(nameof(Details), new { id });
        }
        catch (Exception ex)
        {
            await tx.RollbackAsync();

            TempData["Error"] = "Failed to complete donation: " + ex.Message;

            if (ex.InnerException != null)
            {
                TempData["Error"] += " | Inner: " + ex.InnerException.Message;
            }

            return RedirectToAction(nameof(Details), new { id });
        }
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Cancel(long id)
    {
        var donation = await GetDonationForCurrentShelterAsync(id);
        if (donation == null) return NotFound();

        if (donation.Status == "COMPLETED")
        {
            TempData["Error"] = "Completed donation cannot be cancelled.";
            return RedirectToAction(nameof(Details), new { id });
        }

        donation.Status = "CANCELLED";

        await _db.SaveChangesAsync();

        TempData["Success"] = "Donation cancelled successfully.";
        return RedirectToAction(nameof(Details), new { id });
    }

    private async Task<Donation?> GetDonationForCurrentShelterAsync(long donationId)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var shelter = await _db.Shelters
            .FirstOrDefaultAsync(x => x.ShelterId == shelterId);

        if (shelter == null) return null;

        return await _db.Donations
            .Include(x => x.Donor).ThenInclude(d => d!.Person)
            .Include(x => x.Payment)
            .Include(x => x.Ngo)
            .Include(x => x.DonationItems)
                .ThenInclude(x => x.Item)
            .FirstOrDefaultAsync(x =>
                x.DonationId == donationId &&
                x.NgoId == shelter.NgoId);
    }

    private async Task RefreshAwaitingDonationNeedsAsync(long shelterId, long itemId)
    {
        var inventory = await _db.ShelterInventory
            .FirstOrDefaultAsync(x =>
                x.ShelterId == shelterId &&
                x.ItemId == itemId);

        if (inventory == null || inventory.Quantity <= 0)
            return;

        var awaitingNeeds = await _db.BeneficiaryNeeds
            .Include(x => x.Beneficiary)
            .Where(x =>
                x.Beneficiary != null &&
                x.Beneficiary.ShelterId == shelterId &&
                x.ItemId == itemId &&
                x.RequestStatus == "AWAITING_DONATION")
            .OrderBy(x => x.CreatedAt)
            .ToListAsync();

        foreach (var need in awaitingNeeds)
        {
            if (inventory.Quantity >= need.RequiredQuantity)
            {
                need.RequestStatus = "READY_FOR_PICKUP";
            }
        }
    }
}