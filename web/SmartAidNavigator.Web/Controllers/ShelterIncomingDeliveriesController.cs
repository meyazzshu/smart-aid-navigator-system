using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.Models;
using SmartAidNavigator.Web.ViewModels;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("SHELTER_MANAGER")]
public class ShelterIncomingDeliveriesController : Controller
{
    private readonly AppDbContext _db;

    public ShelterIncomingDeliveriesController(AppDbContext db)
    {
        _db = db;
    }

    public async Task<IActionResult> Index(string? status, string? search, string? sortBy)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var shelter = await _db.Shelters
            .FirstOrDefaultAsync(x => x.ShelterId == shelterId);

        if (shelter == null)
        {
            return RedirectToAction("Create", "ShelterOnboarding");
        }

        status = string.IsNullOrWhiteSpace(status)
            ? "ALL"
            : status.Trim().ToUpper();

        search = string.IsNullOrWhiteSpace(search)
            ? null
            : search.Trim();

        sortBy = string.IsNullOrWhiteSpace(sortBy)
            ? "newest"
            : sortBy.Trim().ToLower();

        var allDeliveries = await _db.Deliveries
            .Include(x => x.Ngo)
            .Include(x => x.DeliveryItems)
                .ThenInclude(x => x.Item)
            .Where(x => x.ShelterId == shelterId)
            .ToListAsync();

        var rows = allDeliveries.AsEnumerable();

        if (status != "ALL" && Enum.TryParse<DeliveryStatus>(status, true, out var parsedStatus))
        {
            rows = rows.Where(x => x.Status == parsedStatus);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            rows = rows.Where(x =>
                x.DeliveryId.ToString().Contains(search, StringComparison.OrdinalIgnoreCase) ||
                (x.Ngo?.NgoName ?? "").Contains(search, StringComparison.OrdinalIgnoreCase) ||
                (x.Notes ?? "").Contains(search, StringComparison.OrdinalIgnoreCase) ||
                x.DeliveryItems.Any(di =>
                    (di.Item?.ItemName ?? "").Contains(search, StringComparison.OrdinalIgnoreCase)));
        }

        rows = sortBy switch
        {
            "oldest" => rows.OrderBy(x => x.CreatedAt),
            "scheduled-asc" => rows.OrderByDescending(x => x.ScheduledDate.HasValue).ThenBy(x => x.ScheduledDate),
            "scheduled-desc" => rows.OrderByDescending(x => x.ScheduledDate.HasValue).ThenByDescending(x => x.ScheduledDate),
            "status" => rows.OrderBy(x => x.Status.ToString()),
            "ngo-az" => rows.OrderBy(x => x.Ngo?.NgoName),
            "qty-high" => rows.OrderByDescending(x => x.DeliveryItems.Sum(i => i.Quantity)),
            "planned" => rows.OrderByDescending(x => x.Status == DeliveryStatus.PLANNED).ThenByDescending(x => x.CreatedAt),
            "routed" => rows.OrderByDescending(x => x.Status == DeliveryStatus.ROUTED).ThenByDescending(x => x.CreatedAt),
            "in-transit" => rows.OrderByDescending(x => x.Status == DeliveryStatus.IN_TRANSIT).ThenByDescending(x => x.CreatedAt),
            "delivered" => rows.OrderByDescending(x => x.Status == DeliveryStatus.DELIVERED).ThenByDescending(x => x.CreatedAt),
            "cancelled" => rows.OrderByDescending(x => x.Status == DeliveryStatus.CANCELLED).ThenByDescending(x => x.CreatedAt),
            _ => rows.OrderByDescending(x => x.CreatedAt)
        };

        var vm = new ShelterIncomingDeliveryIndexVm
        {
            ShelterName = shelter.ShelterName,

            Status = status,
            Search = search,
            SortBy = sortBy,

            TotalCount = allDeliveries.Count,
            PlannedCount = allDeliveries.Count(x => x.Status == DeliveryStatus.PLANNED),
            RoutedCount = allDeliveries.Count(x => x.Status == DeliveryStatus.ROUTED),
            InTransitCount = allDeliveries.Count(x => x.Status == DeliveryStatus.IN_TRANSIT),
            DeliveredCount = allDeliveries.Count(x => x.Status == DeliveryStatus.DELIVERED),
            CancelledCount = allDeliveries.Count(x => x.Status == DeliveryStatus.CANCELLED),

            Rows = rows.Select(x => new ShelterIncomingDeliveryRowVm
            {
                DeliveryId = x.DeliveryId,
                NgoName = x.Ngo?.NgoName ?? "-",
                Status = x.Status,
                ScheduledDate = x.ScheduledDate,
                CreatedAt = x.CreatedAt,
                DistanceKm = x.DistanceKm,
                EtaMinutes = x.EtaMinutes,
                Notes = x.Notes,
                ItemTypeCount = x.DeliveryItems.Count,
                TotalQuantity = x.DeliveryItems.Sum(i => i.Quantity),
                Items = x.DeliveryItems
                    .OrderBy(i => i.Item?.ItemName)
                    .Select(i => new ShelterIncomingDeliveryItemVm
                    {
                        ItemId = i.ItemId,
                        ItemName = i.Item?.ItemName ?? "-",
                        Unit = i.Item?.Unit ?? "-",
                        Quantity = i.Quantity
                    })
                    .ToList()
            }).ToList()
        };

        return View(vm);
    }

    public async Task<IActionResult> Details(long id)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var delivery = await _db.Deliveries
            .Include(x => x.Ngo)
            .Include(x => x.Shelter)
            .Include(x => x.DeliveryItems)
                .ThenInclude(x => x.Item)
            .FirstOrDefaultAsync(x =>
                x.DeliveryId == id &&
                x.ShelterId == shelterId);

        if (delivery == null)
        {
            return NotFound();
        }

        var groupDelivery = await _db.DeliveryGroupDeliveries
            .Include(x => x.DeliveryGroup)
            .FirstOrDefaultAsync(x => x.DeliveryId == delivery.DeliveryId);

        var group = groupDelivery?.DeliveryGroup;

        var tracking = await _db.DeliveryTracking
            .Where(x => x.DeliveryId == delivery.DeliveryId)
            .OrderBy(x => x.CreatedAt)
            .Select(x => new ShelterIncomingDeliveryTrackingVm
            {
                Status = x.Status,
                Note = x.Note,
                CreatedAt = x.CreatedAt
            })
            .ToListAsync();

        var vm = new ShelterIncomingDeliveryDetailVm
        {
            DeliveryId = delivery.DeliveryId,
            ShelterName = delivery.Shelter?.ShelterName ?? "-",
            NgoName = delivery.Ngo?.NgoName ?? "-",
            Status = delivery.Status,
            ScheduledDate = delivery.ScheduledDate,
            CreatedAt = delivery.CreatedAt,
            DistanceKm = delivery.DistanceKm ?? group?.TotalDistanceKm,
            EtaMinutes = delivery.EtaMinutes ?? group?.TotalEtaMinutes,
            Notes = !string.IsNullOrWhiteSpace(delivery.Notes)
                ? delivery.Notes
                : group?.Notes,
            ImageLink = delivery.ImageLink,

            Items = delivery.DeliveryItems
                .OrderBy(x => x.Item?.ItemName)
                .Select(x => new ShelterIncomingDeliveryItemVm
                {
                    ItemId = x.ItemId,
                    ItemName = x.Item?.ItemName ?? "-",
                    Unit = x.Item?.Unit ?? "-",
                    Quantity = x.Quantity
                })
                .ToList(),

            TrackingUpdates = tracking
        };

        return View(vm);
    }
}