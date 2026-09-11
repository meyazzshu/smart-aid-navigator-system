using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.Models;
using SmartAidNavigator.Web.ViewModels;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("SHELTER_MANAGER")]
public class ShelterInventoryController : Controller
{
    private readonly AppDbContext _db;
    public ShelterInventoryController(AppDbContext db) => _db = db;

    public async Task<IActionResult> Index(
    string? search,
    int? categoryId,
    string? stockFilter,
    string? sourceType)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var shelter = await _db.Shelters.FirstAsync(s => s.ShelterId == shelterId);

        stockFilter = string.IsNullOrWhiteSpace(stockFilter)
            ? "in-stock"
            : stockFilter.Trim().ToLower();

        search = string.IsNullOrWhiteSpace(search)
            ? null
            : search.Trim();

        sourceType = string.IsNullOrWhiteSpace(sourceType)
            ? null
            : sourceType.Trim().ToUpper();

        var allowedSourceTypes = new[] { "DONATION", "MANUAL_ADJUSTMENT" };

        if (!string.IsNullOrWhiteSpace(sourceType) && !allowedSourceTypes.Contains(sourceType))
        {
            sourceType = null;
        }

        var latestSourceRows = await _db.InventoryTransactions
            .Where(x => x.OwnerType == "SHELTER" && x.OwnerId == shelterId)
            .OrderByDescending(x => x.CreatedAt)
            .ThenByDescending(x => x.TransactionId)
            .Select(x => new
            {
                x.ItemId,
                x.SourceType
            })
            .ToListAsync();

        var latestSourceLookup = latestSourceRows
            .GroupBy(x => x.ItemId)
            .ToDictionary(
                g => g.Key,
                g => g.First().SourceType
            );

        var allRows = await (
            from item in _db.AidItems
            join cat in _db.AidCategories on item.CategoryId equals cat.CategoryId
            join inv in _db.ShelterInventory.Where(x => x.ShelterId == shelterId)
                on item.ItemId equals inv.ItemId into invj
            from inv in invj.DefaultIfEmpty()
            where item.IsActive
            orderby cat.CategoryName, item.ItemName
            select new InventoryRowVm
            {
                ItemId = item.ItemId,
                CategoryId = cat.CategoryId,
                CategoryName = cat.CategoryName,
                ItemName = item.ItemName,
                Unit = item.Unit,
                Quantity = inv != null ? inv.Quantity : 0,
                MinimumLevel = inv != null ? inv.MinimumLevel : 0,
                UpdatedAt = inv != null ? inv.UpdatedAt : DateTime.MinValue
            })
            .ToListAsync();

        foreach (var row in allRows)
        {
            row.SourceType = latestSourceLookup.ContainsKey(row.ItemId)
                ? latestSourceLookup[row.ItemId]
                : null;
        }

        var totalItemTypes = allRows.Count;
        var inStockCount = allRows.Count(x => x.Quantity > 0);
        var zeroStockCount = allRows.Count(x => x.Quantity <= 0);
        var lowStockCount = allRows.Count(x => x.MinimumLevel > 0 && x.Quantity < x.MinimumLevel);
        var totalQuantity = allRows.Sum(x => x.Quantity);

        var rows = allRows.AsEnumerable();

        rows = stockFilter switch
        {
            "all" => rows,
            "zero" => rows.Where(x => x.Quantity <= 0),
            "low" => rows.Where(x => x.MinimumLevel > 0 && x.Quantity < x.MinimumLevel),
            "in-stock" => rows.Where(x => x.Quantity > 0),
            _ => rows.Where(x => x.Quantity > 0)
        };

        if (categoryId.HasValue)
        {
            rows = rows.Where(x => x.CategoryId == categoryId.Value);
        }

        if (!string.IsNullOrWhiteSpace(sourceType))
        {
            rows = rows.Where(x => x.SourceType == sourceType);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            rows = rows.Where(x =>
                x.ItemName.Contains(search, StringComparison.OrdinalIgnoreCase) ||
                x.CategoryName.Contains(search, StringComparison.OrdinalIgnoreCase) ||
                x.Unit.Contains(search, StringComparison.OrdinalIgnoreCase));
        }

        var categories = await _db.AidCategories
            .OrderBy(x => x.CategoryName)
            .Select(x => new InventoryCategoryFilterVm
            {
                CategoryId = x.CategoryId,
                CategoryName = x.CategoryName
            })
            .ToListAsync();

        return View(new InventoryIndexVm
        {
            ShelterId = shelterId,
            ShelterName = shelter.ShelterName,

            StockFilter = stockFilter,
            CategoryId = categoryId,
            Search = search,
            SourceType = sourceType,

            Categories = categories,

            TotalItemTypes = totalItemTypes,
            InStockCount = inStockCount,
            ZeroStockCount = zeroStockCount,
            LowStockCount = lowStockCount,
            TotalQuantity = totalQuantity,

            Rows = rows.ToList()
        });
    }

    [HttpGet]
    public async Task<IActionResult> Adjust(long itemId)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var item = await _db.AidItems.FirstOrDefaultAsync(x => x.ItemId == itemId);
        if (item == null) return NotFound();

        ViewBag.ItemName = item.ItemName;
        ViewBag.ItemId = item.ItemId;

        return View(new StockAdjustVm { ItemId = itemId, TransactionType = "IN", Quantity = 1 });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Adjust(StockAdjustVm vm)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);
        var userId = CurrentUserHelper.GetUserId(HttpContext);

        if (shelterId == 0)
        {
            TempData["Error"] = "Shelter profile not found.";
            return RedirectToAction("Dashboard", "ShelterManager");
        }

        if (!ModelState.IsValid)
        {
            return View(vm);
        }

        var allowedTypes = new[] { "IN", "OUT", "ADJUST" };

        vm.TransactionType = (vm.TransactionType ?? "").Trim().ToUpper();

        if (!allowedTypes.Contains(vm.TransactionType))
        {
            ModelState.AddModelError(nameof(vm.TransactionType), "Invalid transaction type.");
            return View(vm);
        }

        if (vm.Quantity < 0)
        {
            ModelState.AddModelError(nameof(vm.Quantity), "Quantity cannot be negative.");
            return View(vm);
        }

        var itemExists = await _db.AidItems.AnyAsync(x => x.ItemId == vm.ItemId && x.IsActive);

        if (!itemExists)
        {
            ModelState.AddModelError(nameof(vm.ItemId), "Selected item is invalid or inactive.");
            return View(vm);
        }

        using var tx = await _db.Database.BeginTransactionAsync();

        try
        {
            var inventory = await _db.ShelterInventory
                .FirstOrDefaultAsync(x => x.ShelterId == shelterId && x.ItemId == vm.ItemId);

            if (inventory == null)
            {
                inventory = new ShelterInventory
                {
                    ShelterId = shelterId,
                    ItemId = vm.ItemId,
                    Quantity = 0,
                    MinimumLevel = 0,
                    UpdatedAt = DateTime.UtcNow
                };

                _db.ShelterInventory.Add(inventory);
            }

            if (vm.TransactionType == "IN")
            {
                inventory.Quantity += vm.Quantity;
            }
            else if (vm.TransactionType == "OUT")
            {
                inventory.Quantity = Math.Max(0, inventory.Quantity - vm.Quantity);
            }
            else if (vm.TransactionType == "ADJUST")
            {
                inventory.Quantity = vm.Quantity;
            }

            inventory.UpdatedAt = DateTime.UtcNow;

            _db.InventoryTransactions.Add(new InventoryTransaction
            {
                OwnerType = "SHELTER",
                OwnerId = shelterId,
                ItemId = vm.ItemId,
                TransactionType = vm.TransactionType,
                Quantity = vm.Quantity,
                SourceType = "MANUAL_ADJUSTMENT",
                SourceId = null,
                Note = string.IsNullOrWhiteSpace(vm.Note)
                    ? $"Manual shelter inventory {vm.TransactionType}."
                    : vm.Note.Trim(),
                CreatedBy = userId,
                CreatedAt = DateTime.UtcNow
            });

            await RefreshAwaitingDonationNeedsAsync(shelterId, vm.ItemId);

            await _db.SaveChangesAsync();
            await tx.CommitAsync();

            TempData["Success"] = "Shelter inventory updated and transaction recorded.";
            return RedirectToAction(nameof(Index));
        }
        catch (Exception ex)
        {
            await tx.RollbackAsync();

            TempData["Error"] = "Failed to update inventory: " + ex.Message;

            if (ex.InnerException != null)
            {
                TempData["Error"] += " | Inner: " + ex.InnerException.Message;
            }

            return RedirectToAction(nameof(Index));
        }
    }

    [HttpGet]
    [RequireRole("SHELTER_MANAGER")]
    public async Task<IActionResult> AddStock()
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var shelter = await _db.Shelters
            .FirstOrDefaultAsync(x => x.ShelterId == shelterId);

        if (shelter == null)
        {
            TempData["Error"] = "Shelter profile not found.";
            return RedirectToAction("Dashboard", "ShelterManager");
        }

        var rows = await (
            from item in _db.AidItems.Include(x => x.Category)
            join inv in _db.ShelterInventory.Where(x => x.ShelterId == shelterId)
                on item.ItemId equals inv.ItemId into invJoin
            from inv in invJoin.DefaultIfEmpty()
            where item.IsActive
            orderby item.Category!.CategoryName, item.ItemName
            select new ShelterAddStockItemVm
            {
                ItemId = item.ItemId,
                ItemName = item.ItemName,
                CategoryName = item.Category != null ? item.Category.CategoryName : "-",
                Unit = item.Unit ?? "unit",
                CurrentQuantity = inv != null ? inv.Quantity : 0,
                MinimumLevel = inv != null ? inv.MinimumLevel : 0,
                AddQuantity = 0
            }
        ).ToListAsync();

        var vm = new ShelterAddStockVm
        {
            ShelterName = shelter.ShelterName,
            Items = rows
        };

        return View(vm);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireRole("SHELTER_MANAGER")]
    public async Task<IActionResult> AddStock(ShelterAddStockVm vm)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);
        var userId = CurrentUserHelper.GetUserId(HttpContext);

        var shelter = await _db.Shelters
            .FirstOrDefaultAsync(x => x.ShelterId == shelterId);

        if (shelter == null)
        {
            TempData["Error"] = "Shelter profile not found.";
            return RedirectToAction("Dashboard", "ShelterManager");
        }

        vm.Items ??= new List<ShelterAddStockItemVm>();

        var selectedRows = vm.Items
            .Where(x => x.AddQuantity > 0)
            .ToList();

        if (!selectedRows.Any())
        {
            TempData["Error"] = "Please add stock quantity for at least one item.";
            return RedirectToAction(nameof(AddStock));
        }

        var selectedItemIds = selectedRows
            .Select(x => x.ItemId)
            .Distinct()
            .ToList();

        var validItemIds = await _db.AidItems
            .Where(x => selectedItemIds.Contains(x.ItemId) && x.IsActive)
            .Select(x => x.ItemId)
            .ToListAsync();

        if (validItemIds.Count != selectedItemIds.Count)
        {
            TempData["Error"] = "Some selected items are invalid or inactive.";
            return RedirectToAction(nameof(AddStock));
        }

        using var tx = await _db.Database.BeginTransactionAsync();

        try
        {
            foreach (var row in selectedRows)
            {
                var inventory = await _db.ShelterInventory
                    .FirstOrDefaultAsync(x =>
                        x.ShelterId == shelterId &&
                        x.ItemId == row.ItemId);

                if (inventory == null)
                {
                    inventory = new ShelterInventory
                    {
                        ShelterId = shelterId,
                        ItemId = row.ItemId,
                        Quantity = 0,
                        MinimumLevel = 0,
                        UpdatedAt = DateTime.UtcNow
                    };

                    _db.ShelterInventory.Add(inventory);
                }

                inventory.Quantity += row.AddQuantity;
                inventory.UpdatedAt = DateTime.UtcNow;

                _db.InventoryTransactions.Add(new InventoryTransaction
                {
                    OwnerType = "SHELTER",
                    OwnerId = shelterId,
                    ItemId = row.ItemId,
                    TransactionType = "IN",
                    Quantity = row.AddQuantity,
                    SourceType = "MANUAL_ADJUSTMENT",
                    SourceId = null,
                    Note = string.IsNullOrWhiteSpace(vm.Note)
                        ? "Stock added from shelter inventory page."
                        : vm.Note.Trim(),
                    CreatedBy = userId,
                    CreatedAt = DateTime.UtcNow
                });

                await RefreshAwaitingDonationNeedsAsync(shelterId, row.ItemId);
            }

            await _db.SaveChangesAsync();
            await tx.CommitAsync();

            TempData["Success"] = "Stock added successfully.";
            return RedirectToAction(nameof(Index));
        }
        catch (Exception ex)
        {
            await tx.RollbackAsync();

            TempData["Error"] = "Failed to add stock: " + ex.Message;

            if (ex.InnerException != null)
            {
                TempData["Error"] += " | Inner: " + ex.InnerException.Message;
            }

            return RedirectToAction(nameof(AddStock));
        }
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
