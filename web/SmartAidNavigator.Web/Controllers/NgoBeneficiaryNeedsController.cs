using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.ViewModels;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("NGO_STAFF")]
public class NgoBeneficiaryNeedsController : Controller
{
    private readonly AppDbContext _db;

    public NgoBeneficiaryNeedsController(AppDbContext db)
    {
        _db = db;
    }

    public async Task<IActionResult> Index(
        string? search,
        string? status,
        string? priority,
        long? shelterId,
        string? sortBy)
    {
        var ngoId = await CurrentUserHelper.GetMyNgoIdAsync(HttpContext, _db);

        var ngo = await _db.Ngos.FirstOrDefaultAsync(x => x.NgoId == ngoId);
        if (ngo == null) return RedirectToAction("Create", "NgoOnboarding");

        search = string.IsNullOrWhiteSpace(search) ? null : search.Trim();
        status = string.IsNullOrWhiteSpace(status) ? null : status.Trim().ToUpper();
        priority = string.IsNullOrWhiteSpace(priority) ? null : priority.Trim().ToUpper();
        sortBy = string.IsNullOrWhiteSpace(sortBy) ? "newest" : sortBy.Trim().ToLower();

        var ngoState = (ngo.State ?? "").Trim().ToUpperInvariant();

        var nearbyStates = GetNearbyStates(ngoState)
            .Select(x => x.ToUpperInvariant())
            .ToList();

        var allActiveShelters = await _db.Shelters
            .Where(x => x.IsActive)
            .OrderBy(x => x.State)
            .ThenBy(x => x.ShelterName)
            .ToListAsync();

        var visibleShelters = allActiveShelters
            .Where(x =>
            {
                var shelterState = (x.State ?? "").Trim().ToUpperInvariant();

                return
                    x.NgoId == ngoId ||
                    shelterState == ngoState ||
                    nearbyStates.Contains(shelterState);
            })
            .ToList();

        var ngoShelters = visibleShelters
            .Select(x => new NgoBeneficiaryNeedShelterFilterVm
            {
                ShelterId = x.ShelterId,
                ShelterName = $"{x.ShelterName} ({(x.State ?? "").Trim().ToUpperInvariant()})"
            })
            .ToList();

        var ngoShelterIds = ngoShelters.Select(x => x.ShelterId).ToList();

        var allNeeds = await _db.BeneficiaryNeeds
            .Include(x => x.Beneficiary)!.ThenInclude(x => x!.Person)
            .Include(x => x.Beneficiary)!.ThenInclude(x => x!.Shelter)
            .Include(x => x.Item)!.ThenInclude(x => x!.Category)
            .Where(x =>
                x.Beneficiary != null &&
                ngoShelterIds.Contains(x.Beneficiary.ShelterId))
            .ToListAsync();

        var shelterInventory = await _db.ShelterInventory
            .Where(x => ngoShelterIds.Contains(x.ShelterId))
            .ToListAsync();

        var ngoInventory = await _db.NgoInventory
            .Where(x => x.NgoId == ngoId)
            .ToListAsync();

        var allRows = allNeeds.Select(x =>
        {
            var shelterStock = shelterInventory
                .FirstOrDefault(inv =>
                    inv.ShelterId == x.Beneficiary!.ShelterId &&
                    inv.ItemId == x.ItemId);

            var ngoStock = ngoInventory
                .FirstOrDefault(inv => inv.ItemId == x.ItemId);

            return new NgoBeneficiaryNeedRowVm
            {
                NeedId = x.NeedId,
                BeneficiaryName = x.Beneficiary?.Person?.FullName ?? "-",
                ShelterName = x.Beneficiary?.Shelter?.ShelterName ?? "-",
                ShelterId = x.Beneficiary?.ShelterId ?? 0,

                ItemId = x.ItemId,
                ItemName = x.Item?.ItemName ?? "-",
                CategoryName = x.Item?.Category?.CategoryName ?? "-",
                Unit = x.Item?.Unit ?? "-",

                RequiredQuantity = x.RequiredQuantity,
                ShelterStockQuantity = shelterStock?.Quantity ?? 0,
                NgoStockQuantity = ngoStock?.Quantity ?? 0,

                CanCreateDelivery =
                    x.RequestStatus == "AWAITING_DONATION" &&
                    (ngoStock?.Quantity ?? 0) > 0,

                Priority = x.Priority,
                RequestStatus = x.RequestStatus,
                Notes = x.Notes,
                CreatedAt = x.CreatedAt
            };
        }).ToList();

        var rows = allRows.AsEnumerable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            rows = rows.Where(x =>
                x.BeneficiaryName.Contains(search, StringComparison.OrdinalIgnoreCase) ||
                x.ShelterName.Contains(search, StringComparison.OrdinalIgnoreCase) ||
                x.ItemName.Contains(search, StringComparison.OrdinalIgnoreCase) ||
                x.CategoryName.Contains(search, StringComparison.OrdinalIgnoreCase) ||
                (x.Notes ?? "").Contains(search, StringComparison.OrdinalIgnoreCase));
        }

        if (!string.IsNullOrWhiteSpace(status))
        {
            rows = rows.Where(x => x.RequestStatus == status);
        }

        if (!string.IsNullOrWhiteSpace(priority))
        {
            rows = rows.Where(x => x.Priority == priority);
        }

        if (shelterId.HasValue)
        {
            rows = rows.Where(x => x.ShelterId == shelterId.Value);
        }

        rows = sortBy switch
        {
            "awaiting" => rows.OrderByDescending(x => x.RequestStatus == "AWAITING_DONATION"),
            "ready" => rows.OrderByDescending(x => x.RequestStatus == "READY_FOR_PICKUP"),
            "high-critical" => rows.OrderByDescending(x => x.Priority == "CRITICAL" || x.Priority == "HIGH"),
            "ngo-stock" => rows.OrderByDescending(x => x.NgoStockQuantity),
            "shortage" => rows.OrderBy(x => x.NgoStockQuantity - x.RequiredQuantity),
            "oldest" => rows.OrderBy(x => x.CreatedAt),
            "shelter-az" => rows.OrderBy(x => x.ShelterName),
            "item-az" => rows.OrderBy(x => x.ItemName),
            _ => rows.OrderByDescending(x => x.CreatedAt)
        };

        return View(new NgoBeneficiaryNeedIndexVm
        {
            NgoId = ngoId,
            NgoName = ngo.NgoName,

            Search = search,
            Status = status,
            Priority = priority,
            ShelterId = shelterId,
            SortBy = sortBy,

            TotalCount = allRows.Count,
            AwaitingDonationCount = allRows.Count(x => x.RequestStatus == "AWAITING_DONATION"),
            ReadyForPickupCount = allRows.Count(x => x.RequestStatus == "READY_FOR_PICKUP"),
            HighCriticalCount = allRows.Count(x => x.Priority == "HIGH" || x.Priority == "CRITICAL"),

            Shelters = ngoShelters,
            Rows = rows.ToList()
        });
    }

    public async Task<IActionResult> Details(long id)
    {
        var ngoId = await CurrentUserHelper.GetMyNgoIdAsync(HttpContext, _db);

        var ngo = await _db.Ngos.FirstOrDefaultAsync(x => x.NgoId == ngoId);
        if (ngo == null) return RedirectToAction("Create", "NgoOnboarding");

        var ngoState = (ngo.State ?? "").Trim().ToUpperInvariant();

        var nearbyStates = GetNearbyStates(ngoState)
            .Select(x => x.ToUpperInvariant())
            .ToList();

        var allActiveShelters = await _db.Shelters
            .Where(x => x.IsActive)
            .ToListAsync();

        var visibleShelterIds = allActiveShelters
            .Where(x =>
            {
                var shelterState = (x.State ?? "").Trim().ToUpperInvariant();

                return
                    x.NgoId == ngoId ||
                    shelterState == ngoState ||
                    nearbyStates.Contains(shelterState);
            })
            .Select(x => x.ShelterId)
            .ToList();

        var need = await _db.BeneficiaryNeeds
            .Include(x => x.Beneficiary)!.ThenInclude(x => x!.Person)
            .Include(x => x.Beneficiary)!.ThenInclude(x => x!.Shelter)
            .Include(x => x.Item)!.ThenInclude(x => x!.Category)
            .FirstOrDefaultAsync(x =>
                x.NeedId == id &&
                x.Beneficiary != null &&
                visibleShelterIds.Contains(x.Beneficiary.ShelterId));

        if (need == null) return NotFound();

        ViewBag.NgoName = ngo.NgoName;

        ViewBag.ShelterStock = await _db.ShelterInventory
            .Where(x =>
                x.ShelterId == need.Beneficiary!.ShelterId &&
                x.ItemId == need.ItemId)
            .Select(x => x.Quantity)
            .FirstOrDefaultAsync();

        ViewBag.NgoStock = await _db.NgoInventory
            .Where(x =>
                x.NgoId == ngoId &&
                x.ItemId == need.ItemId)
            .Select(x => x.Quantity)
            .FirstOrDefaultAsync();

        return View(need);
    }

    private static List<string> GetNearbyStates(string state)
    {
        state = state.Trim().ToUpperInvariant();

        return state switch
        {
            "KUALA LUMPUR" => new() { "SELANGOR", "PUTRAJAYA", "NEGERI SEMBILAN" },
            "SELANGOR" => new() { "KUALA LUMPUR", "PUTRAJAYA", "NEGERI SEMBILAN", "PERAK", "PAHANG" },
            "PUTRAJAYA" => new() { "SELANGOR", "KUALA LUMPUR", "NEGERI SEMBILAN" },

            "JOHOR" => new() { "MELAKA", "NEGERI SEMBILAN", "PAHANG" },
            "MELAKA" => new() { "JOHOR", "NEGERI SEMBILAN" },
            "NEGERI SEMBILAN" => new() { "SELANGOR", "PUTRAJAYA", "KUALA LUMPUR", "MELAKA", "JOHOR", "PAHANG" },

            "PAHANG" => new() { "SELANGOR", "NEGERI SEMBILAN", "JOHOR", "TERENGGANU", "KELANTAN", "PERAK" },
            "PERAK" => new() { "SELANGOR", "PAHANG", "KELANTAN", "KEDAH", "PULAU PINANG" },
            "PULAU PINANG" => new() { "KEDAH", "PERAK" },
            "KEDAH" => new() { "PERLIS", "PULAU PINANG", "PERAK" },
            "PERLIS" => new() { "KEDAH" },

            "KELANTAN" => new() { "TERENGGANU", "PAHANG", "PERAK" },
            "TERENGGANU" => new() { "KELANTAN", "PAHANG" },

            "SABAH" => new() { "SARAWAK", "LABUAN" },
            "SARAWAK" => new() { "SABAH", "LABUAN" },
            "LABUAN" => new() { "SABAH", "SARAWAK" },

            _ => new()
        };
    }
}