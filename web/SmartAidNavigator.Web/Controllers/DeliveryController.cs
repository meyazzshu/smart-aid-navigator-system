using SmartAidNavigator.Web.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Models;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;

namespace SmartAidNavigator.Web.Controllers
{
    [RequireRole("NGO_STAFF")]
    public class DeliveryController : Controller
    {
        private readonly AppDbContext _db;
        private readonly IConfiguration _configuration;

        public DeliveryController(AppDbContext db, IConfiguration configuration)
        {
            _db = db;
            _configuration = configuration;
        }

        private void LoadGoogleMapsApiKey()
        {
            ViewBag.GoogleMapsApiKey = _configuration["GoogleMaps:ApiKey"]
                ?? Environment.GetEnvironmentVariable("GOOGLE_MAPS_API_KEY");
        }

        public async Task<IActionResult> Index(
            string? status,
            long? shelterId,
            int? priorityId,
            DateOnly? scheduledFrom,
            DateOnly? scheduledTo,
            string? search,
            string? sortBy)
        {
            var userId = CurrentUserHelper.GetUserId(HttpContext);

            var ngoStaff = await _db.NgoStaff
                .FirstOrDefaultAsync(x => x.UserId == userId);

            if (ngoStaff == null)
            {
                return RedirectToAction("Create", "NgoOnboarding");
            }

            var ngoId = ngoStaff.NgoId;

            var ngo = await _db.Ngos.FirstOrDefaultAsync(x => x.NgoId == ngoId);
            if (ngo == null)
            {
                return RedirectToAction("Create", "NgoOnboarding");
            }

            status = string.IsNullOrWhiteSpace(status)
                ? "ALL"
                : status.Trim().ToUpper();

            search = string.IsNullOrWhiteSpace(search)
                ? null
                : search.Trim();

            sortBy = string.IsNullOrWhiteSpace(sortBy)
                ? "created-desc"
                : sortBy.Trim().ToLower();

            var allDeliveriesForStats = await _db.Deliveries
                .Where(x => x.NgoId == ngoId)
                .ToListAsync();

            var activeStatuses = new[]
            {
                DeliveryStatus.PLANNED,
                DeliveryStatus.ROUTED,
                DeliveryStatus.IN_TRANSIT
            };

            var deliveriesQuery = _db.Deliveries
                .Include(x => x.Shelter)
                .Include(x => x.PriorityCategory)
                .Include(x => x.DeliveryItems)
                    .ThenInclude(x => x.Item)
                .Where(x => x.NgoId == ngoId)
                .AsQueryable();

            if (status == "ACTIVE")
            {
                deliveriesQuery = deliveriesQuery
                    .Where(x => activeStatuses.Contains(x.Status));
            }
            else if (status != "ALL" &&
                     Enum.TryParse<DeliveryStatus>(status, true, out var parsedStatus))
            {
                deliveriesQuery = deliveriesQuery
                    .Where(x => x.Status == parsedStatus);
            }

            if (shelterId.HasValue)
            {
                deliveriesQuery = deliveriesQuery
                    .Where(x => x.ShelterId == shelterId.Value);
            }

            if (priorityId.HasValue)
            {
                deliveriesQuery = deliveriesQuery
                    .Where(x => x.PriorityId == priorityId.Value);
            }

            if (scheduledFrom.HasValue)
            {
                deliveriesQuery = deliveriesQuery
                    .Where(x => x.ScheduledDate >= scheduledFrom.Value);
            }

            if (scheduledTo.HasValue)
            {
                deliveriesQuery = deliveriesQuery
                    .Where(x => x.ScheduledDate <= scheduledTo.Value);
            }

            var deliveries = await deliveriesQuery
                .OrderByDescending(x => x.CreatedAt)
                .ThenByDescending(x => x.DeliveryId)
                .ToListAsync();

            if (!string.IsNullOrWhiteSpace(search))
            {
                deliveries = deliveries
                    .Where(x =>
                        x.DeliveryId.ToString().Contains(search, StringComparison.OrdinalIgnoreCase) ||
                        (x.Shelter?.ShelterName ?? "").Contains(search, StringComparison.OrdinalIgnoreCase) ||
                        (x.Notes ?? "").Contains(search, StringComparison.OrdinalIgnoreCase) ||
                        x.DeliveryItems.Any(di =>
                            (di.Item?.ItemName ?? "").Contains(search, StringComparison.OrdinalIgnoreCase) ||
                            (di.Item?.Unit ?? "").Contains(search, StringComparison.OrdinalIgnoreCase)))
                    .ToList();
            }

            var rowsQuery = deliveries
            .Select(delivery => new DeliveryListRowVm
            {
                DeliveryId = delivery.DeliveryId,
                ShelterName = delivery.Shelter?.ShelterName ?? "-",
                ShelterCity = delivery.Shelter?.City,
                ShelterState = delivery.Shelter?.State,
                Status = delivery.Status,
                ScheduledDate = delivery.ScheduledDate,
                Notes = delivery.Notes,
                PriorityId = delivery.PriorityId,
                PriorityName = delivery.PriorityCategory?.PriorityName,
                PriorityScore = delivery.PriorityScore,
                CreatedAt = delivery.CreatedAt,

                Items = delivery.DeliveryItems
                    .OrderBy(x => x.Item?.ItemName)
                    .Select(x => new DeliveryListItemVm
                    {
                        ItemId = x.ItemId,
                        ItemName = x.Item?.ItemName ?? "-",
                        Unit = x.Item?.Unit ?? "-",
                        Quantity = x.Quantity
                    })
                    .ToList()
            });

            var rows = sortBy switch
            {
                "created-asc" => rowsQuery
                    .OrderBy(x => x.CreatedAt)
                    .ThenBy(x => x.DeliveryId)
                    .ToList(),

                "id-desc" => rowsQuery
                    .OrderByDescending(x => x.DeliveryId)
                    .ToList(),

                "id-asc" => rowsQuery
                    .OrderBy(x => x.DeliveryId)
                    .ToList(),

                "scheduled-desc" => rowsQuery
                    .OrderByDescending(x => x.ScheduledDate.HasValue)
                    .ThenByDescending(x => x.ScheduledDate)
                    .ThenByDescending(x => x.CreatedAt)
                    .ToList(),

                "scheduled-asc" => rowsQuery
                    .OrderByDescending(x => x.ScheduledDate.HasValue)
                    .ThenBy(x => x.ScheduledDate)
                    .ThenByDescending(x => x.CreatedAt)
                    .ToList(),

                "shelter-asc" => rowsQuery
                    .OrderBy(x => x.ShelterName)
                    .ThenByDescending(x => x.CreatedAt)
                    .ToList(),

                "status-asc" => rowsQuery
                    .OrderBy(x => x.Status.ToString())
                    .ThenByDescending(x => x.CreatedAt)
                    .ToList(),

                "priority-desc" => rowsQuery
                    .OrderByDescending(x => x.PriorityScore.HasValue)
                    .ThenByDescending(x => x.PriorityScore)
                    .ThenByDescending(x => x.CreatedAt)
                    .ToList(),

                "priority-asc" => rowsQuery
                    .OrderByDescending(x => x.PriorityScore.HasValue)
                    .ThenBy(x => x.PriorityScore)
                    .ThenByDescending(x => x.CreatedAt)
                    .ToList(),

                "created-desc" or _ => rowsQuery
                    .OrderByDescending(x => x.CreatedAt)
                    .ThenByDescending(x => x.DeliveryId)
                    .ToList()
            };

            var shelters = await _db.Shelters
                .OrderBy(x => x.ShelterName)
                .Select(x => new SelectListItem
                {
                    Value = x.ShelterId.ToString(),
                    Text = x.ShelterName
                })
                .ToListAsync();

            var priorities = await _db.PriorityCategories
                .OrderBy(x => x.PriorityId)
                .Select(x => new SelectListItem
                {
                    Value = x.PriorityId.ToString(),
                    Text = x.PriorityName
                })
                .ToListAsync();

            var vm = new DeliveryIndexViewModel
            {
                NgoName = ngo.NgoName,

                Status = status,
                ShelterId = shelterId,
                PriorityId = priorityId,
                ScheduledFrom = scheduledFrom,
                ScheduledTo = scheduledTo,
                Search = search,
                SortBy = sortBy,

                Shelters = shelters,
                Priorities = priorities,

                ActiveCount = allDeliveriesForStats.Count(x => activeStatuses.Contains(x.Status)),
                PlannedCount = allDeliveriesForStats.Count(x => x.Status == DeliveryStatus.PLANNED),
                RoutedCount = allDeliveriesForStats.Count(x => x.Status == DeliveryStatus.ROUTED),
                InTransitCount = allDeliveriesForStats.Count(x => x.Status == DeliveryStatus.IN_TRANSIT),
                DeliveredCount = allDeliveriesForStats.Count(x => x.Status == DeliveryStatus.DELIVERED),
                CancelledCount = allDeliveriesForStats.Count(x => x.Status == DeliveryStatus.CANCELLED),
                TotalDeliveryCount = allDeliveriesForStats.Count,

                Deliveries = rows
            };

            return View(vm);
        }

        public async Task<IActionResult> Details(long id)
        {
            var userId = CurrentUserHelper.GetUserId(HttpContext);

            var ngoStaff = await _db.NgoStaff
                .FirstOrDefaultAsync(x => x.UserId == userId);

            if (ngoStaff == null)
            {
                return RedirectToAction("Create", "NgoOnboarding");
            }

            var ngoId = ngoStaff.NgoId;

            var delivery = await _db.Deliveries
                .Include(x => x.Ngo)
                .Include(x => x.Shelter)
                .Include(x => x.PriorityCategory)
                .FirstOrDefaultAsync(x => x.DeliveryId == id && x.NgoId == ngoId);

            if (delivery == null)
            {
                return NotFound();
            }

            var items = await _db.DeliveryItems
                .Include(x => x.Item)
                .Where(x => x.DeliveryId == delivery.DeliveryId)
                .OrderBy(x => x.Item!.ItemName)
                .Select(x => new DeliveryListItemVm
                {
                    ItemId = x.ItemId,
                    ItemName = x.Item != null ? x.Item.ItemName : "-",
                    Unit = x.Item != null ? x.Item.Unit : "-",
                    Quantity = x.Quantity
                })
                .ToListAsync();

            var tracking = await _db.DeliveryTracking
                .Where(x => x.DeliveryId == delivery.DeliveryId)
                .OrderByDescending(x => x.CreatedAt)
                .Select(x => new DeliveryTrackingRowVm
                {
                    Status = x.Status,
                    Note = x.Note,
                    CreatedAt = x.CreatedAt
                })
                .ToListAsync();

            var vm = new DeliveryDetailVm
            {
                DeliveryId = delivery.DeliveryId,
                NgoName = delivery.Ngo?.NgoName ?? "-",
                ShelterId = delivery.ShelterId,
                ShelterName = delivery.Shelter?.ShelterName ?? "-",
                ShelterPhone = delivery.Shelter?.Phone,
                ShelterEmail = delivery.Shelter?.Email,
                ShelterAddress = delivery.Shelter?.AddressLine,
                ShelterCity = delivery.Shelter?.City,
                ShelterState = delivery.Shelter?.State,
                ShelterPostalCode = delivery.Shelter?.PostalCode,
                Status = delivery.Status,
                ScheduledDate = delivery.ScheduledDate,
                Notes = delivery.Notes,
                ImageLink = delivery.ImageLink,
                PriorityId = delivery.PriorityId,
                PriorityName = delivery.PriorityCategory?.PriorityName,
                PriorityScore = delivery.PriorityScore,
                CreatedAt = delivery.CreatedAt,
                Items = items,
                TrackingUpdates = tracking
            };

            return View(vm);
        }

        [HttpGet]
        public async Task<IActionResult> Edit(long id)
        {
            LoadGoogleMapsApiKey();

            var userId = CurrentUserHelper.GetUserId(HttpContext);

            var ngoStaff = await _db.NgoStaff
                .FirstOrDefaultAsync(x => x.UserId == userId);

            if (ngoStaff == null)
            {
                return RedirectToAction("Create", "NgoOnboarding");
            }

            var delivery = await _db.Deliveries
                .Include(x => x.Ngo)
                .Include(x => x.Shelter)
                .Include(x => x.DeliveryItems)
                    .ThenInclude(x => x.Item)
                .FirstOrDefaultAsync(x => x.DeliveryId == id && x.NgoId == ngoStaff.NgoId);

            if (delivery == null)
            {
                return NotFound();
            }

            if (delivery.Status == DeliveryStatus.DELIVERED || delivery.Status == DeliveryStatus.CANCELLED)
            {
                TempData["Error"] = "Delivered or cancelled deliveries cannot be edited.";
                return RedirectToAction(nameof(Details), new { id });
            }

            var vm = new DeliveryEditVm
            {
                DeliveryId = delivery.DeliveryId,
                NgoName = delivery.Ngo?.NgoName ?? "-",
                ShelterId = delivery.ShelterId,
                SelectedShelterName = delivery.Shelter?.ShelterName,
                SelectedShelterLatitude = delivery.Shelter?.Latitude,
                SelectedShelterLongitude = delivery.Shelter?.Longitude,
                Status = delivery.Status,
                ScheduledDate = delivery.ScheduledDate,
                PriorityId = delivery.PriorityId,
                Notes = delivery.Notes,
                CreatedAt = delivery.CreatedAt,
                DeliveryItems = delivery.DeliveryItems
                    .OrderBy(x => x.Item?.ItemName)
                    .Select(x => new DeliveryCreateItemVm
                    {
                        ItemId = x.ItemId,
                        Quantity = x.Quantity
                    })
                    .ToList()
            };

            if (!vm.DeliveryItems.Any())
            {
                vm.DeliveryItems.Add(new DeliveryCreateItemVm { Quantity = 1 });
            }

            vm = await BuildDeliveryEditVmAsync(vm, ngoStaff.NgoId);

            return View(vm);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(DeliveryEditVm vm)
        {
            LoadGoogleMapsApiKey();

            var userId = CurrentUserHelper.GetUserId(HttpContext);

            var ngoStaff = await _db.NgoStaff
                .FirstOrDefaultAsync(x => x.UserId == userId);

            if (ngoStaff == null)
            {
                return RedirectToAction("Create", "NgoOnboarding");
            }

            var delivery = await _db.Deliveries
                .Include(x => x.DeliveryItems)
                .FirstOrDefaultAsync(x => x.DeliveryId == vm.DeliveryId && x.NgoId == ngoStaff.NgoId);

            if (delivery == null)
            {
                return NotFound();
            }

            if (delivery.Status == DeliveryStatus.DELIVERED || delivery.Status == DeliveryStatus.CANCELLED)
            {
                TempData["Error"] = "Delivered or cancelled deliveries cannot be edited.";
                return RedirectToAction(nameof(Details), new { id = vm.DeliveryId });
            }

            vm.DeliveryItems ??= new List<DeliveryCreateItemVm>();

            vm.DeliveryItems = vm.DeliveryItems
                .Where(x => x.ItemId.HasValue || x.Quantity > 0)
                .ToList();

            if (!vm.DeliveryItems.Any())
            {
                ModelState.AddModelError(nameof(vm.DeliveryItems), "Please add at least one item for this delivery.");
            }

            var validItems = vm.DeliveryItems
                .Where(x => x.ItemId.HasValue && x.Quantity > 0)
                .ToList();

            if (validItems.Count != vm.DeliveryItems.Count)
            {
                ModelState.AddModelError(nameof(vm.DeliveryItems), "Please make sure every item row has an item and quantity.");
            }

            var duplicateItemIds = validItems
                .GroupBy(x => x.ItemId!.Value)
                .Where(g => g.Count() > 1)
                .Select(g => g.Key)
                .ToList();

            if (duplicateItemIds.Any())
            {
                ModelState.AddModelError(nameof(vm.DeliveryItems), "Duplicate items are not allowed. Increase the quantity in one row instead.");
            }

            var selectedItemIds = validItems
                .Select(x => x.ItemId!.Value)
                .Distinct()
                .ToList();

            var activeItemCount = await _db.AidItems
                .CountAsync(x => selectedItemIds.Contains(x.ItemId) && x.IsActive);

            if (activeItemCount != selectedItemIds.Count)
            {
                ModelState.AddModelError(nameof(vm.DeliveryItems), "Some selected items are invalid or inactive.");
            }

            var shelter = await _db.Shelters
                .FirstOrDefaultAsync(x => x.ShelterId == vm.ShelterId);

            if (shelter == null)
            {
                ModelState.AddModelError(nameof(vm.ShelterId), "Selected shelter does not exist.");
            }

            if (vm.Status == DeliveryStatus.ROUTED)
            {
                var ngo = await _db.Ngos.FirstOrDefaultAsync(x => x.NgoId == ngoStaff.NgoId);

                if (ngo == null || !ngo.Latitude.HasValue || !ngo.Longitude.HasValue ||
                    shelter == null || !shelter.Latitude.HasValue || !shelter.Longitude.HasValue)
                {
                    ModelState.AddModelError(nameof(vm.Status), "Cannot set this delivery to Routed because NGO or shelter coordinates are missing.");
                }
            }

            if (vm.Status == DeliveryStatus.DELIVERED || vm.Status == DeliveryStatus.CANCELLED)
            {
                ModelState.AddModelError(nameof(vm.Status), "Use the delivery details page to mark delivery as delivered or cancelled.");
            }

            if (!ModelState.IsValid)
            {
                vm = await BuildDeliveryEditVmAsync(vm, ngoStaff.NgoId);
                return View(vm);
            }

            using var tx = await _db.Database.BeginTransactionAsync();

            var currentDeliveryItems = await _db.DeliveryItems
                .Where(x => x.DeliveryId == vm.DeliveryId)
                .ToListAsync();

            var currentReservedByItem = currentDeliveryItems
                .GroupBy(x => x.ItemId)
                .ToDictionary(g => g.Key, g => g.Sum(x => x.Quantity));

            var ngoStockRows = await _db.NgoInventory
                .Where(x => x.NgoId == ngoStaff.NgoId && selectedItemIds.Contains(x.ItemId))
                .ToListAsync();

            foreach (var item in validItems)
            {
                var itemId = item.ItemId!.Value;
                var stock = ngoStockRows.FirstOrDefault(x => x.ItemId == itemId);
                var currentReserved = currentReservedByItem.ContainsKey(itemId)
                    ? currentReservedByItem[itemId]
                    : 0;

                var availableForEdit = (stock?.Quantity ?? 0) + currentReserved;

                if (item.Quantity > availableForEdit)
                {
                    ModelState.AddModelError(
                        nameof(vm.DeliveryItems),
                        $"Selected quantity for item ID {itemId} is more than available NGO stock. Available including current delivery quantity: {availableForEdit}."
                    );
                    break;
                }
            }

            try
            {
                var oldStatus = delivery.Status;

                delivery.ShelterId = vm.ShelterId;
                delivery.ScheduledDate = vm.ScheduledDate;
                delivery.PriorityId = vm.PriorityId;
                delivery.Notes = vm.Notes;
                delivery.Status = vm.Status;

                if (oldStatus != vm.Status)
                {
                    _db.DeliveryTracking.Add(new DeliveryTracking
                    {
                        DeliveryId = delivery.DeliveryId,
                        Status = vm.Status,
                        Latitude = null,
                        Longitude = null,
                        Note = "Status updated from delivery edit page.",
                        CreatedAt = DateTime.UtcNow
                    });
                }

                var oldItems = delivery.DeliveryItems
                    .Select(x => new DeliveryItem
                    {
                        DeliveryId = x.DeliveryId,
                        ItemId = x.ItemId,
                        Quantity = x.Quantity
                    })
                    .ToList();

                await ReturnNgoInventoryForDeliveryAsync(
                    ngoStaff.NgoId,
                    delivery.DeliveryId,
                    oldItems,
                    userId,
                    $"Previous delivery items returned before editing delivery #{delivery.DeliveryId}."
                );

                if (delivery.DeliveryItems.Any())
                {
                    _db.DeliveryItems.RemoveRange(delivery.DeliveryItems);
                }

                foreach (var item in validItems)
                {
                    _db.DeliveryItems.Add(new DeliveryItem
                    {
                        DeliveryId = delivery.DeliveryId,
                        ItemId = item.ItemId!.Value,
                        Quantity = item.Quantity
                    });
                }

                await DeductNgoInventoryForDeliveryAsync(
                    ngoStaff.NgoId,
                    delivery.DeliveryId,
                    validItems,
                    userId,
                    $"Updated delivery items deducted for delivery #{delivery.DeliveryId}."
                );

                await _db.SaveChangesAsync();
                await tx.CommitAsync();

                TempData["Success"] = $"Delivery #{delivery.DeliveryId} updated successfully.";
                return RedirectToAction(nameof(Details), new { id = delivery.DeliveryId });
            }
            catch
            {
                await tx.RollbackAsync();

                ModelState.AddModelError("", "Failed to update delivery. Please try again.");
                vm = await BuildDeliveryEditVmAsync(vm, ngoStaff.NgoId);
                return View(vm);
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> UpdateStatus(long id, string status, string? note)
        {
            var userId = CurrentUserHelper.GetUserId(HttpContext);

            var ngoStaff = await _db.NgoStaff
                .FirstOrDefaultAsync(x => x.UserId == userId);

            if (ngoStaff == null)
            {
                return RedirectToAction("Create", "NgoOnboarding");
            }

            var ngoId = ngoStaff.NgoId;

            var delivery = await _db.Deliveries
                .Include(x => x.DeliveryItems)
                .FirstOrDefaultAsync(x => x.DeliveryId == id && x.NgoId == ngoId);

            if (delivery == null)
            {
                return NotFound();
            }

            if (!Enum.TryParse<DeliveryStatus>(status, true, out var newStatus))
            {
                TempData["Error"] = "Invalid delivery status.";
                return RedirectToAction(nameof(Details), new { id });
            }

            if (delivery.Status == DeliveryStatus.CANCELLED)
            {
                TempData["Error"] = "Cancelled delivery cannot be updated.";
                return RedirectToAction(nameof(Details), new { id });
            }

            if (delivery.Status == DeliveryStatus.DELIVERED && newStatus != DeliveryStatus.DELIVERED)
            {
                TempData["Error"] = "Delivered delivery cannot be changed to another status.";
                return RedirectToAction(nameof(Details), new { id });
            }

            using var tx = await _db.Database.BeginTransactionAsync();

            try
            {
                var oldStatus = delivery.Status;

                if (newStatus == DeliveryStatus.CANCELLED &&
                    oldStatus != DeliveryStatus.CANCELLED &&
                    oldStatus != DeliveryStatus.DELIVERED)
                {
                    await ReturnNgoInventoryForDeliveryAsync(
                        ngoId,
                        delivery.DeliveryId,
                        delivery.DeliveryItems.ToList(),
                        userId,
                        $"Stock returned because delivery #{delivery.DeliveryId} was cancelled."
                    );
                }

                delivery.Status = newStatus;

                _db.DeliveryTracking.Add(new DeliveryTracking
                {
                    DeliveryId = delivery.DeliveryId,
                    Status = newStatus,
                    Latitude = null,
                    Longitude = null,
                    Note = note,
                    CreatedAt = DateTime.UtcNow
                });

                await _db.SaveChangesAsync();
                await tx.CommitAsync();
            }
            catch (Exception ex)
            {
                await tx.RollbackAsync();

                TempData["Error"] = "Failed to update delivery status and inventory: " + ex.Message;

                return RedirectToAction(nameof(Details), new { id });
            }

            TempData["Success"] = $"Delivery status updated to {GetStatusDisplay(newStatus)}.";
            return RedirectToAction(nameof(Details), new { id });
        }

        private async Task DeductNgoInventoryForDeliveryAsync(
    long ngoId,
    long deliveryId,
    List<DeliveryCreateItemVm> items,
    long userId,
    string note)
        {
            foreach (var item in items)
            {
                var itemId = item.ItemId!.Value;

                var inventory = await _db.NgoInventory
                    .FirstOrDefaultAsync(x => x.NgoId == ngoId && x.ItemId == itemId);

                if (inventory == null || inventory.Quantity < item.Quantity)
                {
                    throw new InvalidOperationException(
                        $"Not enough NGO inventory for item ID {itemId}. Available: {inventory?.Quantity ?? 0}."
                    );
                }

                inventory.Quantity -= item.Quantity;
                inventory.UpdatedAt = DateTime.UtcNow;

                _db.InventoryTransactions.Add(new InventoryTransaction
                {
                    OwnerType = "NGO",
                    OwnerId = ngoId,
                    ItemId = itemId,
                    TransactionType = "OUT",
                    Quantity = item.Quantity,
                    SourceType = "DELIVERY",
                    SourceId = deliveryId,
                    Note = note,
                    CreatedBy = userId,
                    CreatedAt = DateTime.UtcNow
                });
            }
        }

        private async Task ReturnNgoInventoryForDeliveryAsync(
            long ngoId,
            long deliveryId,
            List<DeliveryItem> items,
            long userId,
            string note)
        {
            foreach (var item in items)
            {
                var inventory = await _db.NgoInventory
                    .FirstOrDefaultAsync(x => x.NgoId == ngoId && x.ItemId == item.ItemId);

                if (inventory == null)
                {
                    inventory = new NgoInventory
                    {
                        NgoId = ngoId,
                        ItemId = item.ItemId,
                        Quantity = 0,
                        MinimumLevel = 0,
                        UpdatedAt = DateTime.UtcNow
                    };

                    _db.NgoInventory.Add(inventory);
                }

                inventory.Quantity += item.Quantity;
                inventory.UpdatedAt = DateTime.UtcNow;

                _db.InventoryTransactions.Add(new InventoryTransaction
                {
                    OwnerType = "NGO",
                    OwnerId = ngoId,
                    ItemId = item.ItemId,
                    TransactionType = "IN",
                    Quantity = item.Quantity,
                    SourceType = "DELIVERY",
                    SourceId = deliveryId,
                    Note = note,
                    CreatedBy = userId,
                    CreatedAt = DateTime.UtcNow
                }); 
            }
        }

        private static string GetStatusDisplay(DeliveryStatus status)
        {
            return status switch
            {
                DeliveryStatus.IN_TRANSIT => "In Transit",
                _ => System.Globalization.CultureInfo.CurrentCulture.TextInfo
                    .ToTitleCase(status.ToString().ToLower())
            };
        }

        public async Task<IActionResult> Create(long? beneficiaryNeedId)
        {
            var userId = CurrentUserHelper.GetUserId(HttpContext);

            var ngoId = await _db.NgoStaff
                .Where(x => x.UserId == userId)
                .Select(x => x.NgoId)
                .FirstOrDefaultAsync();

            if (ngoId == 0)
            {
                return RedirectToAction("Create", "NgoOnboarding");
            }

            var model = new DeliveryCreateVm
            {
                NgoId = ngoId,
                DeliveryItems = new List<DeliveryCreateItemVm>
        {
            new DeliveryCreateItemVm
            {
                Quantity = 1
            }
        }
            };

            if (beneficiaryNeedId.HasValue)
            {
                var need = await GetVisibleAwaitingBeneficiaryNeedAsync(beneficiaryNeedId.Value, ngoId);

                if (need == null)
                {
                    TempData["Error"] = "Beneficiary need not found, not visible to your NGO, or not awaiting donation.";
                    return RedirectToAction("Index", "NgoBeneficiaryNeeds");
                }

                model.BeneficiaryNeedId = need.NeedId;
                model.ShelterId = need.Beneficiary!.ShelterId;
                model.DeliveryItems = new List<DeliveryCreateItemVm>
        {
            new DeliveryCreateItemVm
            {
                ItemId = need.ItemId,
                Quantity = need.RequiredQuantity
            }
        };

                model.Notes =
                    $"Created from beneficiary need #{need.NeedId}. " +
                    $"Beneficiary: {need.Beneficiary?.Person?.FullName ?? "-"}. " +
                    $"Item: {need.Item?.ItemName ?? "-"}. " +
                    $"Priority: {need.Priority}. " +
                    $"Need notes: {need.Notes ?? "-"}";
            }

            model = await BuildDeliveryCreateVmAsync(model, ngoId);

            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(DeliveryCreateVm model)
        {
            var userId = CurrentUserHelper.GetUserId(HttpContext);

            var ngoId = await _db.NgoStaff
                .Where(x => x.UserId == userId)
                .Select(x => x.NgoId)
                .FirstOrDefaultAsync();

            if (ngoId == 0)
            {
                return RedirectToAction("Create", "NgoOnboarding");
            }

            // Force current user's NGO only.
            model.NgoId = ngoId;

            model.DeliveryItems ??= new List<DeliveryCreateItemVm>();

            // Remove completely empty rows if user clicks add row but does not fill it.
            model.DeliveryItems = model.DeliveryItems
                .Where(x => x.ItemId.HasValue || x.Quantity > 0)
                .ToList();

            if (!model.DeliveryItems.Any())
            {
                ModelState.AddModelError(nameof(model.DeliveryItems), "Please add at least one item for this delivery.");
            }

            var validItems = model.DeliveryItems
                .Where(x => x.ItemId.HasValue && x.Quantity > 0)
                .ToList();

            if (validItems.Count != model.DeliveryItems.Count)
            {
                ModelState.AddModelError(nameof(model.DeliveryItems), "Please make sure every item row has an item and quantity.");
            }

            var duplicateItemIds = validItems
                .GroupBy(x => x.ItemId!.Value)
                .Where(g => g.Count() > 1)
                .Select(g => g.Key)
                .ToList();

            if (duplicateItemIds.Any())
            {
                ModelState.AddModelError(nameof(model.DeliveryItems), "Duplicate item names are not allowed. Increase the quantity in one row instead.");
            }

            var selectedItemIds = validItems
                .Select(x => x.ItemId!.Value)
                .Distinct()
                .ToList();

            var activeItemCount = await _db.AidItems
                .CountAsync(x => selectedItemIds.Contains(x.ItemId) && x.IsActive);

            if (activeItemCount != selectedItemIds.Count)
            {
                ModelState.AddModelError(nameof(model.DeliveryItems), "Some selected items are invalid or inactive.");
            }

            var ngoStockRows = await _db.NgoInventory
                .Where(x =>
                    x.NgoId == ngoId &&
                    selectedItemIds.Contains(x.ItemId))
                .ToListAsync();

            foreach (var item in validItems)
            {
                var stock = ngoStockRows.FirstOrDefault(x => x.ItemId == item.ItemId!.Value);

                if (stock == null || stock.Quantity <= 0)
                {
                    ModelState.AddModelError(
                        nameof(model.DeliveryItems),
                        "One or more selected items are not available in your NGO inventory."
                    );
                    break;
                }

                if (item.Quantity > stock.Quantity)
                {
                    ModelState.AddModelError(
                        nameof(model.DeliveryItems),
                        $"Selected quantity for item ID {item.ItemId} is more than your NGO stock. Available stock: {stock.Quantity}."
                    );
                    break;
                }
            }

            var shelterExists = await _db.Shelters
                .AnyAsync(x => x.ShelterId == model.ShelterId);

            if (!shelterExists)
            {
                ModelState.AddModelError(nameof(model.ShelterId), "Selected shelter does not exist.");
            }

            if (!ModelState.IsValid)
            {
                model = await BuildDeliveryCreateVmAsync(model, ngoId);
                return View(model);
            }

            using var tx = await _db.Database.BeginTransactionAsync();

            if (model.BeneficiaryNeedId.HasValue)
            {
                var sourceNeed = await GetVisibleAwaitingBeneficiaryNeedAsync(model.BeneficiaryNeedId.Value, ngoId);

                if (sourceNeed == null)
                {
                    ModelState.AddModelError("", "The selected beneficiary need is no longer available for delivery creation.");
                }
                else
                {
                    var matchesNeed = validItems.Any(x =>
                        x.ItemId == sourceNeed.ItemId &&
                        x.Quantity >= sourceNeed.RequiredQuantity);

                    if (!matchesNeed)
                    {
                        ModelState.AddModelError(nameof(model.DeliveryItems), "Delivery items must include the requested aid item and quantity from the beneficiary need.");
                    }

                    if (model.ShelterId != sourceNeed.Beneficiary!.ShelterId)
                    {
                        ModelState.AddModelError(nameof(model.ShelterId), "Shelter must match the beneficiary need shelter.");
                    }
                }

                if (!ModelState.IsValid)
                {
                    model = await BuildDeliveryCreateVmAsync(model, ngoId);
                    return View(model);
                }
            }

            var delivery = new Delivery
            {
                NgoId = ngoId,
                ShelterId = model.ShelterId,
                Status = DeliveryStatus.PLANNED,
                ScheduledDate = model.ScheduledDate,
                Notes = model.Notes,
                CreatedAt = DateTime.UtcNow
            };

            _db.Deliveries.Add(delivery);
            await _db.SaveChangesAsync();

            _db.DeliveryTracking.Add(new DeliveryTracking
            {
                DeliveryId = delivery.DeliveryId,
                Status = DeliveryStatus.PLANNED,
                Latitude = null,
                Longitude = null,
                Note = "Delivery has been planned by the NGO.",
                CreatedAt = DateTime.UtcNow
            });

            await _db.SaveChangesAsync();

            foreach (var item in validItems)
            {
                _db.DeliveryItems.Add(new DeliveryItem
                {
                    DeliveryId = delivery.DeliveryId,
                    ItemId = item.ItemId!.Value,
                    Quantity = item.Quantity
                });
            }

            await DeductNgoInventoryForDeliveryAsync(
                ngoId,
                delivery.DeliveryId,
                validItems,
                userId,
                $"Stock deducted for delivery #{delivery.DeliveryId}."
            );

            await _db.SaveChangesAsync();
            await tx.CommitAsync();

            TempData["Success"] = "Delivery created successfully with multiple items.";
            return RedirectToAction(nameof(Index));
        }

        private async Task<DeliveryCreateVm> BuildDeliveryCreateVmAsync(DeliveryCreateVm model, long ngoId)
        {
            model.Ngos = await _db.Ngos
                .Where(n => n.NgoId == ngoId)
                .Select(n => new SelectListItem
                {
                    Value = n.NgoId.ToString(),
                    Text = n.NgoName
                })
                .ToListAsync();

            model.Shelters = await _db.Shelters
                .OrderBy(s => s.ShelterName)
                .Select(s => new SelectListItem
                {
                    Value = s.ShelterId.ToString(),
                    Text = s.ShelterName
                })
                .ToListAsync();

            model.Items = await (
                from inv in _db.NgoInventory
                join item in _db.AidItems on inv.ItemId equals item.ItemId
                where inv.NgoId == ngoId
                      && inv.Quantity > 0
                      && item.IsActive
                orderby item.ItemName
                select new SelectListItem
                {
                    Value = item.ItemId.ToString(),
                    Text = $"{item.ItemName} ({item.Unit}) - Stock: {inv.Quantity}"
                }
            ).ToListAsync();

            if (model.DeliveryItems == null || !model.DeliveryItems.Any())
            {
                model.DeliveryItems = new List<DeliveryCreateItemVm>
                {
                    new DeliveryCreateItemVm
                    {
                        Quantity = 1
                    }
                };
            }

            return model;
        }

        private async Task<DeliveryEditVm> BuildDeliveryEditVmAsync(DeliveryEditVm vm, long ngoId)
        {
            var selectedShelter = await _db.Shelters
                .FirstOrDefaultAsync(x => x.ShelterId == vm.ShelterId);

            vm.SelectedShelterName = selectedShelter?.ShelterName;
            vm.SelectedShelterLatitude = selectedShelter?.Latitude;
            vm.SelectedShelterLongitude = selectedShelter?.Longitude;

            vm.Shelters = await _db.Shelters
                .OrderBy(s => s.ShelterName)
                .Select(s => new SelectListItem
                {
                    Value = s.ShelterId.ToString(),
                    Text = s.ShelterName,
                    Selected = s.ShelterId == vm.ShelterId
                })
                .ToListAsync();

            vm.Priorities = await _db.PriorityCategories
                .OrderBy(x => x.PriorityId)
                .Select(x => new SelectListItem
                {
                    Value = x.PriorityId.ToString(),
                    Text = x.PriorityName,
                    Selected = vm.PriorityId.HasValue && x.PriorityId == vm.PriorityId.Value
                })
                .ToListAsync();

            vm.Items = await (
                from inv in _db.NgoInventory
                join item in _db.AidItems on inv.ItemId equals item.ItemId
                where inv.NgoId == ngoId
                      && inv.Quantity > 0
                      && item.IsActive
                orderby item.ItemName
                select new SelectListItem
                {
                    Value = item.ItemId.ToString(),
                    Text = $"{item.ItemName} ({item.Unit}) - Stock: {inv.Quantity}"
                }
            ).ToListAsync();

            if (vm.DeliveryItems == null || !vm.DeliveryItems.Any())
            {
                vm.DeliveryItems = new List<DeliveryCreateItemVm>
                {
                    new DeliveryCreateItemVm
                    {
                        Quantity = 1
                    }
                };
            }

            return vm;
        }

        [HttpGet]
        public async Task<IActionResult> GetShelterLocation(long shelterId)
        {
            var userId = CurrentUserHelper.GetUserId(HttpContext);

            var ngoStaff = await _db.NgoStaff
                .FirstOrDefaultAsync(x => x.UserId == userId);

            if (ngoStaff == null)
            {
                return Json(new { ok = false });
            }

            var shelter = await _db.Shelters
                .FirstOrDefaultAsync(x => x.ShelterId == shelterId);

            if (shelter == null)
            {
                return Json(new { ok = false });
            }

            return Json(new
            {
                ok = true,
                name = shelter.ShelterName,
                lat = shelter.Latitude,
                lng = shelter.Longitude
            });
        }

        private async Task<BeneficiaryNeed?> GetVisibleAwaitingBeneficiaryNeedAsync(long needId, long ngoId)
        {
            var ngo = await _db.Ngos.FirstOrDefaultAsync(x => x.NgoId == ngoId);
            if (ngo == null) return null;

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

            return await _db.BeneficiaryNeeds
                .Include(x => x.Beneficiary)!.ThenInclude(x => x!.Person)
                .Include(x => x.Item)
                .FirstOrDefaultAsync(x =>
                    x.NeedId == needId &&
                    x.RequestStatus == "AWAITING_DONATION" &&
                    x.Beneficiary != null &&
                    visibleShelterIds.Contains(x.Beneficiary.ShelterId));
        }

        private static List<string> GetNearbyStates(string state)
        {
            state = (state ?? "").Trim().ToUpperInvariant();

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

}