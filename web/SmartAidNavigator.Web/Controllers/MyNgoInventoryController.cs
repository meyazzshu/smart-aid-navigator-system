using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.Models;
using SmartAidNavigator.Web.ViewModels;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("NGO_STAFF")]
public class MyNgoInventoryController : Controller
{
    private readonly AppDbContext _db;

    public MyNgoInventoryController(AppDbContext db)
    {
        _db = db;
    }

    public async Task<IActionResult> Index(
    string? search,
    int? categoryId,
    string? stockFilter,
    string? sourceType)
    {
        var ngoId = await CurrentUserHelper.GetMyNgoIdAsync(HttpContext, _db);

        var ngo = await _db.Ngos.FirstOrDefaultAsync(x => x.NgoId == ngoId);
        if (ngo == null) return RedirectToAction("Create", "NgoOnboarding");

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
            .Where(x => x.OwnerType == "NGO" && x.OwnerId == ngoId)
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
            join inv in _db.NgoInventory.Where(x => x.NgoId == ngoId)
                on item.ItemId equals inv.ItemId into invJoin
            from inv in invJoin.DefaultIfEmpty()
            where item.IsActive
            orderby cat.CategoryName, item.ItemName
            select new MyNgoInventoryRowVm
            {
                ItemId = item.ItemId,
                CategoryId = cat.CategoryId,
                CategoryName = cat.CategoryName,
                ItemName = item.ItemName,
                Unit = item.Unit,
                Quantity = inv != null ? inv.Quantity : 0,
                MinimumLevel = inv != null ? inv.MinimumLevel : 0,
                UpdatedAt = inv != null ? inv.UpdatedAt : DateTime.MinValue
            }
        ).ToListAsync();

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

        return View(new MyNgoInventoryVm
        {
            NgoId = ngoId,
            NgoName = ngo.NgoName,

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
        await CurrentUserHelper.GetMyNgoIdAsync(HttpContext, _db);

        var item = await _db.AidItems.FirstOrDefaultAsync(x => x.ItemId == itemId);
        if (item == null) return NotFound();

        ViewBag.ItemName = item.ItemName;
        ViewBag.ItemId = item.ItemId;

        return View(new MyNgoStockAdjustVm
        {
            ItemId = itemId,
            TransactionType = "IN",
            Quantity = 1
        });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Adjust(MyNgoStockAdjustVm vm)
    {
        var ngoId = await CurrentUserHelper.GetMyNgoIdAsync(HttpContext, _db);
        var userId = CurrentUserHelper.GetUserId(HttpContext);

        if (ngoId == 0)
        {
            TempData["Error"] = "NGO profile not found.";
            return RedirectToAction("Dashboard", "NgoStaff");
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
            var inventory = await _db.NgoInventory
                .FirstOrDefaultAsync(x => x.NgoId == ngoId && x.ItemId == vm.ItemId);

            if (inventory == null)
            {
                inventory = new NgoInventory
                {
                    NgoId = ngoId,
                    ItemId = vm.ItemId,
                    Quantity = 0,
                    MinimumLevel = 0,
                    UpdatedAt = DateTime.UtcNow
                };

                _db.NgoInventory.Add(inventory);
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
                OwnerType = "NGO",
                OwnerId = ngoId,
                ItemId = vm.ItemId,
                TransactionType = vm.TransactionType,
                Quantity = vm.Quantity,
                SourceType = "MANUAL_ADJUSTMENT",
                SourceId = null,
                Note = string.IsNullOrWhiteSpace(vm.Note)
                    ? $"Manual NGO inventory {vm.TransactionType}."
                    : vm.Note.Trim(),
                CreatedBy = userId,
                CreatedAt = DateTime.UtcNow
            });

            await _db.SaveChangesAsync();
            await tx.CommitAsync();

            TempData["Success"] = "NGO inventory updated and transaction recorded.";
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
    [RequireRole("NGO_STAFF")]
    public async Task<IActionResult> AddStock()
    {
        var userId = CurrentUserHelper.GetUserId(HttpContext);

        var ngoStaff = await _db.NgoStaff
            .FirstOrDefaultAsync(x => x.UserId == userId);

        if (ngoStaff == null)
        {
            TempData["Error"] = "Your account is not linked to any NGO.";
            return RedirectToAction("Dashboard", "NgoStaff");
        }

        var ngo = await _db.Ngos
            .FirstOrDefaultAsync(x => x.NgoId == ngoStaff.NgoId);

        if (ngo == null)
        {
            TempData["Error"] = "NGO profile not found.";
            return RedirectToAction("Dashboard", "NgoStaff");
        }

        var rows = await (
            from item in _db.AidItems.Include(x => x.Category)
            join inv in _db.NgoInventory.Where(x => x.NgoId == ngoStaff.NgoId)
                on item.ItemId equals inv.ItemId into invJoin
            from inv in invJoin.DefaultIfEmpty()
            where item.IsActive
            orderby item.Category!.CategoryName, item.ItemName
            select new MyNgoAddStockItemVm
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

        var vm = new MyNgoAddStockVm
        {
            NgoName = ngo.NgoName,
            Items = rows
        };

        return View(vm);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireRole("NGO_STAFF")]
    public async Task<IActionResult> AddStock(MyNgoAddStockVm vm)
    {
        var userId = CurrentUserHelper.GetUserId(HttpContext);

        var ngoStaff = await _db.NgoStaff
            .FirstOrDefaultAsync(x => x.UserId == userId);

        if (ngoStaff == null)
        {
            TempData["Error"] = "Your account is not linked to any NGO.";
            return RedirectToAction("Dashboard", "NgoStaff");
        }

        vm.Items ??= new List<MyNgoAddStockItemVm>();

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
                var inventory = await _db.NgoInventory
                    .FirstOrDefaultAsync(x =>
                        x.NgoId == ngoStaff.NgoId &&
                        x.ItemId == row.ItemId);

                if (inventory == null)
                {
                    inventory = new NgoInventory
                    {
                        NgoId = ngoStaff.NgoId,
                        ItemId = row.ItemId,
                        Quantity = 0,
                        MinimumLevel = 0,
                        UpdatedAt = DateTime.UtcNow
                    };

                    _db.NgoInventory.Add(inventory);
                }

                inventory.Quantity += row.AddQuantity;
                inventory.UpdatedAt = DateTime.UtcNow;

                _db.InventoryTransactions.Add(new InventoryTransaction
                {
                    OwnerType = "NGO",
                    OwnerId = ngoStaff.NgoId,
                    ItemId = row.ItemId,
                    TransactionType = "IN",
                    Quantity = row.AddQuantity,
                    SourceType = "MANUAL_ADJUSTMENT",
                    SourceId = null,
                    Note = string.IsNullOrWhiteSpace(vm.Note)
                        ? "Stock added from NGO inventory page."
                        : vm.Note.Trim(),
                    CreatedBy = userId,
                    CreatedAt = DateTime.UtcNow
                });
            }

            await _db.SaveChangesAsync();
            await tx.CommitAsync();

            TempData["Success"] = "Stock added successfully.";
            return RedirectToAction(nameof(Index));
        }
        catch
        {
            await tx.RollbackAsync();

            TempData["Error"] = "Failed to add stock. Please try again.";
            return RedirectToAction(nameof(AddStock));
        }
    }
}