using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.Models;
using SmartAidNavigator.Web.ViewModels;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("ADMIN")]
public class NgosController : Controller
{
    private readonly AppDbContext _db;
    private readonly IConfiguration _configuration;

    public NgosController(AppDbContext db, IConfiguration configuration)
    {
        _db = db;
        _configuration = configuration;
    }

    private void LoadGoogleMapsApiKey()
    {
        ViewBag.GoogleMapsApiKey = _configuration["GoogleMaps:ApiKey"]
            ?? Environment.GetEnvironmentVariable("GOOGLE_MAPS_API_KEY");
    }

    public async Task<IActionResult> Index()
    {
        var list = await _db.Ngos.OrderByDescending(x => x.CreatedAt).ToListAsync();
        return View(list);
    }

    public async Task<IActionResult> Details(long id)
    {
        var ngo = await _db.Ngos.FirstOrDefaultAsync(x => x.NgoId == id);

        if (ngo == null)
        {
            return NotFound();
        }

        LoadGoogleMapsApiKey();
        return View(ngo);
    }

    public IActionResult Create()
    {
        LoadGoogleMapsApiKey();

        return View(new NgoCreateVm
        {
            IsActive = true,
            OwnerStaffType = "NGO Staff",
            OwnerStaffTitle = "Owner"
        });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(NgoCreateVm vm)
    {
        LoadGoogleMapsApiKey();

        if (!ModelState.IsValid)
        {
            return View(vm);
        }

        var ownerEmail = vm.OwnerEmail.Trim().ToLower();

        var emailExists = await _db.Persons
            .AnyAsync(x => x.Email != null && x.Email.ToLower() == ownerEmail);

        if (emailExists)
        {
            ModelState.AddModelError(nameof(vm.OwnerEmail), "Owner email already exists.");
            return View(vm);
        }

        var ngoStaffRoleId = await _db.Roles
            .Where(x => x.RoleName == "NGO_STAFF")
            .Select(x => (int?)x.RoleId)
            .FirstOrDefaultAsync();

        if (!ngoStaffRoleId.HasValue)
        {
            ModelState.AddModelError("", "NGO_STAFF role was not found.");
            return View(vm);
        }

        using var tx = await _db.Database.BeginTransactionAsync();

        try
        {
            var ngo = new Ngo
            {
                NgoName = vm.NgoName.Trim(),
                Description = string.IsNullOrWhiteSpace(vm.Description) ? null : vm.Description.Trim(),
                Phone = string.IsNullOrWhiteSpace(vm.Phone) ? null : vm.Phone.Trim(),
                Email = string.IsNullOrWhiteSpace(vm.Email) ? null : vm.Email.Trim(),
                IsActive = vm.IsActive,
                IsTaxExempt = vm.IsTaxExempt,
                TaxExemptionNo = string.IsNullOrWhiteSpace(vm.TaxExemptionNo) ? null : vm.TaxExemptionNo.Trim(),
                AddressLine = string.IsNullOrWhiteSpace(vm.AddressLine) ? null : vm.AddressLine.Trim(),
                City = string.IsNullOrWhiteSpace(vm.City) ? null : vm.City.Trim(),
                State = string.IsNullOrWhiteSpace(vm.State) ? null : vm.State.Trim(),
                PostalCode = string.IsNullOrWhiteSpace(vm.PostalCode) ? null : vm.PostalCode.Trim(),
                Latitude = vm.Latitude,
                Longitude = vm.Longitude,
                CreatedAt = DateTime.UtcNow
            };

            if (vm.IsActive)
            {
                ngo.ApprovedBy = CurrentUserHelper.GetUserId(HttpContext);
                ngo.ApprovedAt = DateTime.UtcNow;
            }

            _db.Ngos.Add(ngo);
            await _db.SaveChangesAsync();

            var ownerPerson = new Person
            {
                FullName = vm.OwnerFullName.Trim(),
                Email = ownerEmail,
                Phone = string.IsNullOrWhiteSpace(vm.OwnerPhone) ? null : vm.OwnerPhone.Trim(),
                IcOrPassport = string.IsNullOrWhiteSpace(vm.OwnerIcOrPassport) ? null : vm.OwnerIcOrPassport.Trim(),
                Gender = string.IsNullOrWhiteSpace(vm.OwnerGender) ? null : vm.OwnerGender.Trim(),
                DateOfBirth = vm.OwnerDateOfBirth,

                // owner can use same address as NGO by default
                AddressLine = ngo.AddressLine,
                City = ngo.City,
                State = ngo.State,
                PostalCode = ngo.PostalCode,

                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _db.Persons.Add(ownerPerson);
            await _db.SaveChangesAsync();

            var ownerUser = new User
            {
                PersonId = ownerPerson.PersonId,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(vm.OwnerPassword),
                IsActive = vm.IsActive,
                IsGuest = false,
                CreatedAt = DateTime.UtcNow
            };

            _db.Users.Add(ownerUser);
            await _db.SaveChangesAsync();

            _db.UserRoles.Add(new UserRole
            {
                UserId = ownerUser.UserId,
                RoleId = ngoStaffRoleId.Value
            });

            _db.NgoStaff.Add(new NgoStaff
            {
                NgoId = ngo.NgoId,
                UserId = ownerUser.UserId,
                StaffTitle = "Owner"
            });

            await _db.SaveChangesAsync();
            await tx.CommitAsync();

            TempData["Success"] = "NGO and owner account created successfully.";
            return RedirectToAction(nameof(Details), new { id = ngo.NgoId });
        }
        catch
        {
            await tx.RollbackAsync();

            ModelState.AddModelError("", "Failed to create NGO and owner account. Please try again.");
            return View(vm);
        }
    }

    public async Task<IActionResult> Edit(long id)
    {
        var ngo = await _db.Ngos.FindAsync(id);

        if (ngo == null)
        {
            return NotFound();
        }

        LoadGoogleMapsApiKey();
        return View(ngo);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(long id, Ngo ngo)
    {
        if (id != ngo.NgoId)
        {
            return BadRequest();
        }

        if (!ModelState.IsValid)
        {
            LoadGoogleMapsApiKey();
            return View(ngo);
        }

        _db.Entry(ngo).State = EntityState.Modified;
        await _db.SaveChangesAsync();

        TempData["Success"] = "NGO details updated successfully.";
        return RedirectToAction(nameof(Details), new { id = ngo.NgoId });
    }

    public async Task<IActionResult> Delete(long id)
    {
        var ngo = await _db.Ngos.FindAsync(id);
        if (ngo == null) return NotFound();
        return View(ngo);
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(long id)
    {
        var ngo = await _db.Ngos.FirstOrDefaultAsync(x => x.NgoId == id);

        if (ngo == null)
        {
            return NotFound();
        }

        var hasShelters = await _db.Shelters.AnyAsync(x => x.NgoId == id);
        var hasDeliveries = await _db.Deliveries.AnyAsync(x => x.NgoId == id);
        var hasDonations = await _db.Donations.AnyAsync(x => x.NgoId == id);
        var hasStaff = await _db.NgoStaff.AnyAsync(x => x.NgoId == id);

        if (hasShelters || hasDeliveries || hasDonations || hasStaff)
        {
            TempData["Error"] =
                "This NGO has related shelters, staff, deliveries, or donations. Please deactivate it instead to preserve reports and history.";

            return RedirectToAction(nameof(Delete), new { id });
        }

        _db.Ngos.Remove(ngo);
        await _db.SaveChangesAsync();

        TempData["Success"] = "NGO deleted permanently.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Approve(long id)
    {
        var ngo = await _db.Ngos.FirstOrDefaultAsync(x => x.NgoId == id);

        if (ngo == null)
        {
            return NotFound();
        }

        var staffUserIds = await _db.NgoStaff
            .Where(x => x.NgoId == id)
            .Select(x => x.UserId)
            .ToListAsync();

        var users = await _db.Users
            .Where(x => staffUserIds.Contains(x.UserId))
            .ToListAsync();

        ngo.IsActive = true;
        ngo.ApprovedBy = CurrentUserHelper.GetUserId(HttpContext);
        ngo.ApprovedAt = DateTime.UtcNow;

        foreach (var user in users)
        {
            user.IsActive = true;
        }

        await _db.SaveChangesAsync();

        TempData["Success"] = $"NGO {ngo.NgoName} has been approved.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Deactivate(long id)
    {
        var ngo = await _db.Ngos.FirstOrDefaultAsync(x => x.NgoId == id);

        if (ngo == null)
        {
            return NotFound();
        }

        using var tx = await _db.Database.BeginTransactionAsync();

        try
        {
            ngo.IsActive = false;

            // Deactivate all NGO staff users
            var ngoStaffUserIds = await _db.NgoStaff
                .Where(x => x.NgoId == id)
                .Select(x => x.UserId)
                .ToListAsync();

            var ngoStaffUsers = await _db.Users
                .Where(x => ngoStaffUserIds.Contains(x.UserId))
                .ToListAsync();

            foreach (var user in ngoStaffUsers)
            {
                user.IsActive = false;
            }

            // Deactivate shelters under this NGO
            var shelters = await _db.Shelters
                .Where(x => x.NgoId == id)
                .ToListAsync();

            foreach (var shelter in shelters)
            {
                shelter.IsActive = false;
            }

            var shelterIds = shelters.Select(x => x.ShelterId).ToList();

            // Deactivate shelter manager users under this NGO's shelters
            var shelterManagerUserIds = await _db.ShelterManagers
                .Where(x => shelterIds.Contains(x.ShelterId))
                .Select(x => x.UserId)
                .ToListAsync();

            var shelterManagerUsers = await _db.Users
                .Where(x => shelterManagerUserIds.Contains(x.UserId))
                .ToListAsync();

            foreach (var user in shelterManagerUsers)
            {
                user.IsActive = false;
            }

            // Mark beneficiaries in those shelters as discharged
            var beneficiaries = await _db.Beneficiaries
                .Where(x => shelterIds.Contains(x.ShelterId) && x.Status == "ACTIVE")
                .ToListAsync();

            foreach (var beneficiary in beneficiaries)
            {
                beneficiary.Status = "DISCHARGED";
                beneficiary.DischargedAt = DateTime.UtcNow;
            }

            await _db.SaveChangesAsync();
            await tx.CommitAsync();

            TempData["Success"] = $"NGO '{ngo.NgoName}' has been deactivated. Related NGO staff and shelter manager accounts were disabled. Active beneficiaries under its shelters were discharged, but public user accounts were not deactivated.";
            return RedirectToAction(nameof(Index));
        }
        catch
        {
            await tx.RollbackAsync();
            TempData["Error"] = "Failed to deactivate NGO. Please try again.";
            return RedirectToAction(nameof(Index));
        }
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Reactivate(long id)
    {
        var ngo = await _db.Ngos.FirstOrDefaultAsync(x => x.NgoId == id);

        if (ngo == null)
        {
            return NotFound();
        }

        using var tx = await _db.Database.BeginTransactionAsync();

        try
        {
            ngo.IsActive = true;

            var ngoStaffUserIds = await _db.NgoStaff
                .Where(x => x.NgoId == id)
                .Select(x => x.UserId)
                .ToListAsync();

            var ngoStaffUsers = await _db.Users
                .Where(x => ngoStaffUserIds.Contains(x.UserId))
                .ToListAsync();

            foreach (var user in ngoStaffUsers)
            {
                user.IsActive = true;
            }

            var shelters = await _db.Shelters
                .Where(x => x.NgoId == id)
                .ToListAsync();

            foreach (var shelter in shelters)
            {
                shelter.IsActive = true;
            }

            var shelterIds = shelters.Select(x => x.ShelterId).ToList();

            var shelterManagerUserIds = await _db.ShelterManagers
                .Where(x => shelterIds.Contains(x.ShelterId))
                .Select(x => x.UserId)
                .ToListAsync();

            var shelterManagerUsers = await _db.Users
                .Where(x => shelterManagerUserIds.Contains(x.UserId))
                .ToListAsync();

            foreach (var user in shelterManagerUsers)
            {
                user.IsActive = true;
            }

            await _db.SaveChangesAsync();
            await tx.CommitAsync();

            TempData["Success"] = $"NGO '{ngo.NgoName}' has been reactivated.";
            return RedirectToAction(nameof(Index));
        }
        catch
        {
            await tx.RollbackAsync();

            TempData["Error"] = "Failed to reactivate NGO. Please try again.";
            return RedirectToAction(nameof(Index));
        }
    }
}
