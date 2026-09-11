using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.Models;
using Microsoft.AspNetCore.Mvc.Rendering;
using SmartAidNavigator.Web.ViewModels;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("ADMIN")]
public class SheltersController : Controller
{
    private readonly AppDbContext _db;
    private readonly IConfiguration _configuration;

    public SheltersController(AppDbContext db, IConfiguration configuration)
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
        var list = await _db.Shelters
            .Include(s => s.Ngo)
            .OrderByDescending(s => s.CreatedAt)
            .ToListAsync();

        return View(list);
    }

    public async Task<IActionResult> Details(long id)
    {
        var shelter = await _db.Shelters
            .Include(s => s.Ngo)
            .FirstOrDefaultAsync(s => s.ShelterId == id);

        if (shelter == null)
        {
            return NotFound();
        }

        LoadGoogleMapsApiKey();
        return View(shelter);
    }

    public async Task<IActionResult> Create()
    {
        LoadGoogleMapsApiKey();

        var vm = new ShelterCreateVm
        {
            IsActive = true,
            CurrentOccupancy = 0,
            ManagerStaffType = "Shelter Manager",
            ManagerStaffTitle = "Shelter Manager",
            NgoOptions = await GetNgoOptionsAsync()
        };

        return View(vm);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(ShelterCreateVm vm)
    {
        LoadGoogleMapsApiKey();
        vm.NgoOptions = await GetNgoOptionsAsync(vm.NgoId);

        if (!ModelState.IsValid)
        {
            return View(vm);
        }

        var managerEmail = vm.ManagerEmail.Trim().ToLower();

        var emailExists = await _db.Persons
            .AnyAsync(x => x.Email != null && x.Email.ToLower() == managerEmail);

        if (emailExists)
        {
            ModelState.AddModelError(nameof(vm.ManagerEmail), "Manager email already exists.");
            return View(vm);
        }

        var shelterManagerRoleId = await _db.Roles
            .Where(x => x.RoleName == "SHELTER_MANAGER")
            .Select(x => (int?)x.RoleId)
            .FirstOrDefaultAsync();

        if (!shelterManagerRoleId.HasValue)
        {
            ModelState.AddModelError("", "SHELTER_MANAGER role was not found.");
            return View(vm);
        }

        using var tx = await _db.Database.BeginTransactionAsync();

        try
        {
            var shelter = new Shelter
            {
                ShelterName = vm.ShelterName.Trim(),
                NgoId = vm.NgoId == 0 ? null : vm.NgoId,
                Phone = string.IsNullOrWhiteSpace(vm.Phone) ? null : vm.Phone.Trim(),
                Email = string.IsNullOrWhiteSpace(vm.Email) ? null : vm.Email.Trim(),
                Capacity = vm.Capacity,
                CurrentOccupancy = vm.CurrentOccupancy,
                IsActive = vm.IsActive,
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
                shelter.ApprovedBy = CurrentUserHelper.GetUserId(HttpContext);
                shelter.ApprovedAt = DateTime.UtcNow;
            }

            _db.Shelters.Add(shelter);
            await _db.SaveChangesAsync();

            var managerPerson = new Person
            {
                FullName = vm.ManagerFullName.Trim(),
                Email = managerEmail,
                Phone = string.IsNullOrWhiteSpace(vm.ManagerPhone) ? null : vm.ManagerPhone.Trim(),
                IcOrPassport = string.IsNullOrWhiteSpace(vm.ManagerIcOrPassport) ? null : vm.ManagerIcOrPassport.Trim(),
                Gender = string.IsNullOrWhiteSpace(vm.ManagerGender) ? null : vm.ManagerGender.Trim(),
                DateOfBirth = vm.ManagerDateOfBirth,

                // manager can use same address as shelter by default
                AddressLine = shelter.AddressLine,
                City = shelter.City,
                State = shelter.State,
                PostalCode = shelter.PostalCode,

                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _db.Persons.Add(managerPerson);
            await _db.SaveChangesAsync();

            var managerUser = new User
            {
                PersonId = managerPerson.PersonId,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(vm.ManagerPassword),
                IsActive = vm.IsActive,
                IsGuest = false,
                CreatedAt = DateTime.UtcNow
            };

            _db.Users.Add(managerUser);
            await _db.SaveChangesAsync();

            _db.UserRoles.Add(new UserRole
            {
                UserId = managerUser.UserId,
                RoleId = shelterManagerRoleId.Value
            });

            _db.ShelterManagers.Add(new ShelterManager
            {
                ShelterId = shelter.ShelterId,
                UserId = managerUser.UserId,
                StaffTitle = "Shelter Manager"
            });

            await _db.SaveChangesAsync();
            await tx.CommitAsync();

            TempData["Success"] = "Shelter and shelter manager account created successfully.";
            return RedirectToAction(nameof(Details), new { id = shelter.ShelterId });
        }
        catch
        {
            await tx.RollbackAsync();

            ModelState.AddModelError("", "Failed to create shelter and manager account. Please try again.");
            return View(vm);
        }
    }

    public async Task<IActionResult> Edit(long id)
    {
        var shelter = await _db.Shelters.FindAsync(id);

        if (shelter == null)
        {
            return NotFound();
        }

        ViewBag.Ngos = await _db.Ngos.OrderBy(n => n.NgoName).ToListAsync();
        LoadGoogleMapsApiKey();

        return View(shelter);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(long id, Shelter shelter)
    {
        if (id != shelter.ShelterId)
        {
            return BadRequest();
        }

        ViewBag.Ngos = await _db.Ngos.OrderBy(n => n.NgoName).ToListAsync();

        if (shelter.NgoId == 0)
        {
            shelter.NgoId = null;
        }

        if (!ModelState.IsValid)
        {
            LoadGoogleMapsApiKey();
            return View(shelter);
        }

        _db.Entry(shelter).State = EntityState.Modified;
        await _db.SaveChangesAsync();

        TempData["Success"] = "Shelter details updated successfully.";
        return RedirectToAction(nameof(Details), new { id = shelter.ShelterId });
    }

    public async Task<IActionResult> Delete(long id)
    {
        var shelter = await _db.Shelters
            .Include(s => s.Ngo)
            .FirstOrDefaultAsync(s => s.ShelterId == id);

        if (shelter == null) return NotFound();
        return View(shelter);
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(long id)
    {
        var shelter = await _db.Shelters.FirstOrDefaultAsync(x => x.ShelterId == id);

        if (shelter == null)
        {
            return NotFound();
        }

        var hasManagers = await _db.ShelterManagers.AnyAsync(x => x.ShelterId == id);
        var hasBeneficiaries = await _db.Beneficiaries.AnyAsync(x => x.ShelterId == id);
        var hasInventory = await _db.ShelterInventory.AnyAsync(x => x.ShelterId == id);
        var hasDeliveries = await _db.Deliveries.AnyAsync(x => x.ShelterId == id);
        var hasRequests = await _db.ShelterRequests.AnyAsync(x => x.ShelterId == id);
        var hasAssessments = await _db.ShelterAssessments.AnyAsync(x => x.ShelterId == id);

        if (hasManagers || hasBeneficiaries || hasInventory || hasDeliveries || hasRequests || hasAssessments)
        {
            TempData["Error"] =
                "This shelter has related managers, beneficiaries, inventory, deliveries, requests, or assessments. Please deactivate it instead to preserve reports and history.";

            return RedirectToAction(nameof(Delete), new { id });
        }

        _db.Shelters.Remove(shelter);
        await _db.SaveChangesAsync();

        TempData["Success"] = "Shelter deleted permanently.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Approve(long id)
    {
        var shelter = await _db.Shelters.FirstOrDefaultAsync(x => x.ShelterId == id);

        if (shelter == null)
        {
            return NotFound();
        }

        var managerUserIds = await _db.ShelterManagers
            .Where(x => x.ShelterId == id)
            .Select(x => x.UserId)
            .ToListAsync();

        var users = await _db.Users
            .Where(x => managerUserIds.Contains(x.UserId))
            .ToListAsync();

        shelter.IsActive = true;
        shelter.ApprovedBy = CurrentUserHelper.GetUserId(HttpContext);
        shelter.ApprovedAt = DateTime.UtcNow;

        foreach (var user in users)
        {
            user.IsActive = true;
        }

        await _db.SaveChangesAsync();

        TempData["Success"] = $"Shelter {shelter.ShelterName} has been approved.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Deactivate(long id)
    {
        var shelter = await _db.Shelters.FirstOrDefaultAsync(x => x.ShelterId == id);

        if (shelter == null)
        {
            return NotFound();
        }

        using var tx = await _db.Database.BeginTransactionAsync();

        try
        {
            shelter.IsActive = false;

            // Deactivate shelter manager users
            var managerUserIds = await _db.ShelterManagers
                .Where(x => x.ShelterId == id)
                .Select(x => x.UserId)
                .ToListAsync();

            var managerUsers = await _db.Users
                .Where(x => managerUserIds.Contains(x.UserId))
                .ToListAsync();

            foreach (var user in managerUsers)
            {
                user.IsActive = false;
            }

            // Mark active beneficiaries as discharged
            var beneficiaries = await _db.Beneficiaries
                .Where(x => x.ShelterId == id && x.Status == "ACTIVE")
                .ToListAsync();

            foreach (var beneficiary in beneficiaries)
            {
                beneficiary.Status = "DISCHARGED";
                beneficiary.DischargedAt = DateTime.UtcNow;
            }

            await _db.SaveChangesAsync();
            await tx.CommitAsync();

            TempData["Success"] = $"Shelter '{shelter.ShelterName}' has been deactivated. Related shelter manager accounts were disabled. Active beneficiaries were discharged, but public user accounts were not deactivated.";
            return RedirectToAction(nameof(Index));
        }
        catch
        {
            await tx.RollbackAsync();
            TempData["Error"] = "Failed to deactivate shelter. Please try again.";
            return RedirectToAction(nameof(Index));
        }
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Reactivate(long id)
    {
        var shelter = await _db.Shelters.FirstOrDefaultAsync(x => x.ShelterId == id);

        if (shelter == null)
        {
            return NotFound();
        }

        using var tx = await _db.Database.BeginTransactionAsync();

        try
        {
            shelter.IsActive = true;

            var managerUserIds = await _db.ShelterManagers
                .Where(x => x.ShelterId == id)
                .Select(x => x.UserId)
                .ToListAsync();

            var managerUsers = await _db.Users
                .Where(x => managerUserIds.Contains(x.UserId))
                .ToListAsync();

            foreach (var user in managerUsers)
            {
                user.IsActive = true;
            }

            await _db.SaveChangesAsync();
            await tx.CommitAsync();

            TempData["Success"] = $"Shelter '{shelter.ShelterName}' has been reactivated.";
            return RedirectToAction(nameof(Index));
        }
        catch
        {
            await tx.RollbackAsync();

            TempData["Error"] = "Failed to reactivate shelter. Please try again.";
            return RedirectToAction(nameof(Index));
        }
    }

    private async Task<List<SelectListItem>> GetNgoOptionsAsync(long? selectedNgoId = null)
    {
        return await _db.Ngos
            .OrderBy(x => x.NgoName)
            .Select(x => new SelectListItem
            {
                Value = x.NgoId.ToString(),
                Text = x.IsActive
                    ? x.NgoName
                    : x.NgoName + " (Inactive / Pending)",
                Selected = selectedNgoId.HasValue && x.NgoId == selectedNgoId.Value
            })
            .ToListAsync();
    }
}
