using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.Models;
using SmartAidNavigator.Web.ViewModels;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("NGO_STAFF")]
public class DeliveryGroupsController : Controller
{
    private readonly AppDbContext _db;

    public DeliveryGroupsController(AppDbContext db)
    {
        _db = db;
    }

    public async Task<IActionResult> Index()
    {
        var userId = CurrentUserHelper.GetUserId(HttpContext);

        var ngoStaff = await _db.NgoStaff
            .FirstOrDefaultAsync(x => x.UserId == userId);

        if (ngoStaff == null)
        {
            TempData["Error"] = "Your account is not linked to any NGO.";
            return RedirectToAction("Dashboard", "NgoStaff");
        }

        var groups = await _db.DeliveryGroups
            .Include(g => g.AssignedUser)
                .ThenInclude(u => u.Person)
            .Include(g => g.GroupDeliveries)
            .Where(g => g.NgoId == ngoStaff.NgoId)
            .OrderByDescending(g => g.CreatedAt)
            .ToListAsync();

        return View(groups);
    }

    public async Task<IActionResult> Details(long id)
    {
        var userId = CurrentUserHelper.GetUserId(HttpContext);

        var ngoStaff = await _db.NgoStaff
            .FirstOrDefaultAsync(x => x.UserId == userId);

        if (ngoStaff == null)
        {
            return Forbid();
        }

        var group = await _db.DeliveryGroups
            .Include(g => g.Ngo)
            .Include(g => g.AssignedUser)
                .ThenInclude(u => u.Person)
            .Include(g => g.GroupDeliveries)
                .ThenInclude(gd => gd.Delivery)
                    .ThenInclude(d => d!.Shelter)
            .Include(g => g.GroupDeliveries)
                .ThenInclude(gd => gd.Delivery)
                    .ThenInclude(d => d!.DeliveryItems)
                        .ThenInclude(di => di.Item)
            .FirstOrDefaultAsync(g => g.DeliveryGroupId == id && g.NgoId == ngoStaff.NgoId);

        if (group == null)
        {
            return NotFound();
        }

        group.GroupDeliveries = group.GroupDeliveries
            .OrderBy(gd => gd.OptimizedStopOrder ?? gd.RequestedStopOrder ?? 9999)
            .ThenBy(gd => gd.DeliveryId)
            .ToList();

        return View(group);
    }

    public async Task<IActionResult> Create()
    {
        var vm = await BuildCreateVmAsync(new DeliveryGroupCreateVm());
        return View(vm);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(DeliveryGroupCreateVm vm)
    {
        vm.SelectedDeliveryIds ??= new List<long>();

        if (vm.SelectedDeliveryIds.Count < 2)
        {
            ModelState.AddModelError(nameof(vm.SelectedDeliveryIds), "Please select at least 2 existing deliveries for group delivery.");
        }

        if (!ModelState.IsValid)
        {
            vm = await BuildCreateVmAsync(vm);
            return View(vm);
        }

        var userId = CurrentUserHelper.GetUserId(HttpContext);

        var ngoStaff = await _db.NgoStaff
            .FirstOrDefaultAsync(x => x.UserId == userId);

        if (ngoStaff == null)
        {
            return Forbid();
        }

        var ngo = await _db.Ngos.FirstOrDefaultAsync(n => n.NgoId == ngoStaff.NgoId);

        if (ngo == null)
        {
            return NotFound("NGO not found.");
        }

        var selectedDeliveryIds = vm.SelectedDeliveryIds.Distinct().ToList();

        var selectedDeliveries = await _db.Deliveries
            .Include(d => d.Shelter)
            .Where(d => selectedDeliveryIds.Contains(d.DeliveryId))
            .Where(d => d.NgoId == ngoStaff.NgoId)
            .Where(d => d.Status != DeliveryStatus.DELIVERED && d.Status != DeliveryStatus.CANCELLED)
            .ToListAsync();

        if (selectedDeliveries.Count != selectedDeliveryIds.Count)
        {
            ModelState.AddModelError(nameof(vm.SelectedDeliveryIds), "Some selected deliveries are invalid, delivered, cancelled, or not under your NGO.");
            vm = await BuildCreateVmAsync(vm);
            return View(vm);
        }

        var alreadyGroupedDeliveryIds = await _db.DeliveryGroupDeliveries
            .Where(x => selectedDeliveryIds.Contains(x.DeliveryId))
            .Select(x => x.DeliveryId)
            .ToListAsync();

        if (alreadyGroupedDeliveryIds.Any())
        {
            ModelState.AddModelError(nameof(vm.SelectedDeliveryIds), "Some selected deliveries are already inside another group.");
            vm = await BuildCreateVmAsync(vm);
            return View(vm);
        }

        using var tx = await _db.Database.BeginTransactionAsync();

        var group = new DeliveryGroup
        {
            NgoId = ngoStaff.NgoId,
            AssignedTo = vm.AssignedTo,
            GroupName = vm.GroupName.Trim(),
            ScheduledDate = vm.ScheduledDate,
            Notes = vm.Notes,
            Status = DeliveryStatus.PLANNED,
            OriginLat = ngo.Latitude,
            OriginLng = ngo.Longitude,
            CreatedAt = DateTime.UtcNow
        };

        _db.DeliveryGroups.Add(group);
        await _db.SaveChangesAsync();

        var order = 1;

        foreach (var deliveryId in selectedDeliveryIds)
        {
            _db.DeliveryGroupDeliveries.Add(new DeliveryGroupDelivery
            {
                DeliveryGroupId = group.DeliveryGroupId,
                DeliveryId = deliveryId,
                RequestedStopOrder = order,
                CreatedAt = DateTime.UtcNow
            });

            order++;
        }

        await _db.SaveChangesAsync();
        await tx.CommitAsync();

        TempData["Success"] = "Group delivery created from existing deliveries.";
        return RedirectToAction(nameof(Details), new { id = group.DeliveryGroupId });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> RemoveDelivery(long groupId, long deliveryId)
    {
        var userId = CurrentUserHelper.GetUserId(HttpContext);

        var ngoStaff = await _db.NgoStaff
            .FirstOrDefaultAsync(x => x.UserId == userId);

        if (ngoStaff == null)
        {
            return Forbid();
        }

        var group = await _db.DeliveryGroups
            .FirstOrDefaultAsync(g => g.DeliveryGroupId == groupId && g.NgoId == ngoStaff.NgoId);

        if (group == null)
        {
            return NotFound();
        }

        var link = await _db.DeliveryGroupDeliveries
            .FirstOrDefaultAsync(x => x.DeliveryGroupId == groupId && x.DeliveryId == deliveryId);

        if (link != null)
        {
            _db.DeliveryGroupDeliveries.Remove(link);
            await _db.SaveChangesAsync();
            TempData["Success"] = "Delivery removed from group.";
        }

        return RedirectToAction(nameof(Details), new { id = groupId });
    }

    private async Task<DeliveryGroupCreateVm> BuildCreateVmAsync(DeliveryGroupCreateVm vm)
    {
        var userId = CurrentUserHelper.GetUserId(HttpContext);

        var ngoStaff = await _db.NgoStaff
            .FirstOrDefaultAsync(x => x.UserId == userId);

        if (ngoStaff == null)
        {
            return vm;
        }

        var alreadyGroupedDeliveryIds = await _db.DeliveryGroupDeliveries
            .Select(x => x.DeliveryId)
            .ToListAsync();

        var availableDeliveries = await _db.Deliveries
            .Include(d => d.Shelter)
            .Include(d => d.PriorityCategory)
            .Include(d => d.DeliveryItems)
                .ThenInclude(di => di.Item)
            .Where(d => d.NgoId == ngoStaff.NgoId)

            // Only PLANNED deliveries can be selected for a new group.
            // Hide DELIVERED, CANCELLED, IN_TRANSIT, and ROUTED.
            .Where(d => d.Status == DeliveryStatus.PLANNED)

            .Where(d => !alreadyGroupedDeliveryIds.Contains(d.DeliveryId))

            // Default arrangement: delivery id descending
            .OrderByDescending(d => d.DeliveryId)

            .ToListAsync();

        var selectedIds = vm.SelectedDeliveryIds ?? new List<long>();

        vm.DeliveryCards = availableDeliveries.Select(d =>
        {
            var deliveryItems = d.DeliveryItems ?? new List<DeliveryItem>();

            var itemParts = deliveryItems
                .Where(di => di.Item != null)
                .Select(di => $"{di.Item!.ItemName} x {di.Quantity} {di.Item.Unit}")
                .ToList();

            var status = d.Status.ToString();

            var priorityName = d.PriorityCategory?.PriorityName ?? "-";

            return new DeliveryGroupDeliveryCardVm
            {
                DeliveryId = d.DeliveryId,
                CreatedAt = d.CreatedAt,
                ShelterName = d.Shelter?.ShelterName ?? "-",
                AddressLine = d.Shelter?.AddressLine ?? "",
                City = d.Shelter?.City ?? "",
                State = d.Shelter?.State ?? "",
                Status = status,
                StatusLabel = status == "IN_TRANSIT" ? "IN TRANSIT" : status,
                StatusCssClass = GetDeliveryStatusCssClass(status),
                ScheduledDate = d.ScheduledDate,
                PriorityName = priorityName,
                PriorityCssClass = GetPriorityCssClass(priorityName),
                PriorityScore = d.PriorityScore,
                DistanceKm = d.DistanceKm,
                EtaMinutes = d.EtaMinutes,
                ItemsSummary = itemParts.Any()
                    ? string.Join(", ", itemParts.Take(4)) + (itemParts.Count > 4 ? "..." : "")
                    : "No items added yet",
                ItemTypeCount = deliveryItems.Count,
                TotalQuantity = deliveryItems.Sum(di => di.Quantity),
                IsSelected = selectedIds.Contains(d.DeliveryId)
            };
        }).ToList();

        vm.StaffOptions = await _db.NgoStaff
            .Where(ns => ns.NgoId == ngoStaff.NgoId)
            .Join(
                _db.Users,
                ns => ns.UserId,
                u => u.UserId,
                (ns, u) => u
            )
            .OrderBy(u => u.Person != null ? u.Person.FullName : u.UserId.ToString())
            .Select(u => new SelectListItem
            {
                Value = u.UserId.ToString(),
                Text = u.Person != null ? u.Person.FullName : $"User #{u.UserId}"
            })
            .ToListAsync();

        return vm;
    }

    private static string GetDeliveryStatusCssClass(string status)
    {
        return status switch
        {
            "ROUTED" => "badge-routed",
            "IN_TRANSIT" => "badge-transit",
            "DELIVERED" => "badge-delivered",
            "CANCELLED" => "badge-cancelled",
            _ => "badge-planned"
        };
    }

    private static string GetPriorityCssClass(string priorityName)
    {
        return priorityName.ToLower() switch
        {
            "critical" => "priority-high",
            "high" => "priority-high",
            "medium" => "priority-medium",
            "low" => "priority-low",
            _ => ""
        };
    }
}