using BCrypt.Net;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Models;
using SmartAidNavigator.Web.ViewModels;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("ADMIN")]
public class UsersController : Controller
{
    private readonly AppDbContext _db;
    private readonly IConfiguration _configuration;

    public UsersController(AppDbContext db, IConfiguration configuration)
    {
        _db = db;
        _configuration = configuration;
    }

    private async Task<List<SelectListItem>> GetRoleSelectListAsync()
    {
        return await _db.Roles
            .OrderBy(r => r.RoleName)
            .Select(r => new SelectListItem
            {
                Value = r.RoleId.ToString(),
                Text = r.RoleName
            })
            .ToListAsync();
    }

    public async Task<IActionResult> Index()
    {
        // Load all users + their role names
        var data = await (from u in _db.Users
                          join p in _db.Persons on u.PersonId equals p.PersonId
                          join ur in _db.UserRoles on u.UserId equals ur.UserId into urj
                          from ur in urj.DefaultIfEmpty()
                          join r in _db.Roles on ur.RoleId equals r.RoleId into rj
                          from r in rj.DefaultIfEmpty()
                          select new { u, p, RoleName = r != null ? r.RoleName : "" })
                         .ToListAsync();

        var list = data
            .GroupBy(x => x.u.UserId)
            .Select(g => new UserListItemVm
            {
                UserId = g.First().u.UserId,
                FullName = g.First().p.FullName,
                Email = g.First().p.Email ?? "",
                IsActive = g.First().u.IsActive,
                RolesCsv = string.Join(", ", g.Select(x => x.RoleName).Where(x => !string.IsNullOrWhiteSpace(x)).Distinct())
            })
            .OrderBy(x => x.UserId)
            .ToList();

        return View(list);
    }

    public async Task<IActionResult> Details(long id)
    {
        var user = await _db.Users
            .Include(u => u.Person)
            .FirstOrDefaultAsync(u => u.UserId == id);

        if (user == null || user.Person == null)
        {
            return NotFound();
        }

        var roles = await (
            from ur in _db.UserRoles
            join r in _db.Roles on ur.RoleId equals r.RoleId
            where ur.UserId == id
            select r.RoleName
        ).ToListAsync();

        var ngoInfo = await (
            from ns in _db.NgoStaff
            join n in _db.Ngos on ns.NgoId equals n.NgoId
            where ns.UserId == id
            select new
            {
                n.NgoName,
                ns.StaffTitle
            }
        ).FirstOrDefaultAsync();

        var shelterInfo = await (
            from sm in _db.ShelterManagers
            join s in _db.Shelters on sm.ShelterId equals s.ShelterId
            where sm.UserId == id
            select new
            {
                s.ShelterName
            }
        ).FirstOrDefaultAsync();

        var vm = new UserDetailsVm
        {
            UserId = user.UserId,
            PersonId = user.Person.PersonId,

            FullName = user.Person.FullName,
            Email = user.Person.Email ?? "-",
            Phone = user.Person.Phone,

            IcOrPassport = user.Person.IcOrPassport,
            Gender = user.Person.Gender,
            DateOfBirth = user.Person.DateOfBirth,

            AddressLine = user.Person.AddressLine,
            City = user.Person.City,
            State = user.Person.State,
            PostalCode = user.Person.PostalCode,

            IsActive = user.IsActive,
            IsGuest = user.IsGuest,
            CreatedAt = user.CreatedAt,

            RolesCsv = string.Join(", ", roles),

            NgoName = ngoInfo?.NgoName,
            NgoStaffTitle = ngoInfo?.StaffTitle,

            ShelterName = shelterInfo?.ShelterName
        };

        return View(vm);
    }

    [HttpGet]
    public async Task<IActionResult> Create()
    {
        ViewBag.Roles = await GetRoleSelectListAsync();
        LoadGoogleMapsApiKey();

        return View(new UserCreateVm
        {
            IsActive = true
        });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(UserCreateVm vm)
    {
        ViewBag.Roles = await GetRoleSelectListAsync();
        LoadGoogleMapsApiKey();

        if (!ModelState.IsValid)
        {
            return View(vm);
        }

        var email = vm.Email.Trim().ToLower();

        var exists = await _db.Persons
            .AnyAsync(p => p.Email != null && p.Email.ToLower() == email);

        if (exists)
        {
            ModelState.AddModelError(nameof(vm.Email), "Email already exists.");
            return View(vm);
        }

        var person = new Person
        {
            FullName = vm.FullName.Trim(),
            Email = email,
            Phone = string.IsNullOrWhiteSpace(vm.Phone) ? null : vm.Phone.Trim(),

            IcOrPassport = string.IsNullOrWhiteSpace(vm.IcOrPassport) ? null : vm.IcOrPassport.Trim(),
            Gender = string.IsNullOrWhiteSpace(vm.Gender) ? null : vm.Gender.Trim(),
            DateOfBirth = vm.DateOfBirth,

            AddressLine = string.IsNullOrWhiteSpace(vm.AddressLine) ? null : vm.AddressLine.Trim(),
            City = string.IsNullOrWhiteSpace(vm.City) ? null : vm.City.Trim(),
            State = string.IsNullOrWhiteSpace(vm.State) ? null : vm.State.Trim(),
            PostalCode = string.IsNullOrWhiteSpace(vm.PostalCode) ? null : vm.PostalCode.Trim(),

            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _db.Persons.Add(person);
        await _db.SaveChangesAsync();

        var user = new User
        {
            PersonId = person.PersonId,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(vm.Password),
            IsActive = vm.IsActive,
            IsGuest = false,
            CreatedAt = DateTime.UtcNow
        };

        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        _db.UserRoles.Add(new UserRole
        {
            UserId = user.UserId,
            RoleId = vm.RoleId
        });

        await _db.SaveChangesAsync();

        TempData["Success"] = "User account created successfully.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Edit(long id)
    {
        var user = await _db.Users
            .Include(u => u.Person)
            .FirstOrDefaultAsync(u => u.UserId == id);

        if (user == null) return NotFound();
        if (user.Person == null) return BadRequest();

        var currentRoleId = await _db.UserRoles
            .Where(ur => ur.UserId == id)
            .Select(ur => (int?)ur.RoleId)
            .FirstOrDefaultAsync() ?? 0;

        ViewBag.Roles = await GetRoleSelectListAsync();
        LoadGoogleMapsApiKey();

        var vm = new UserEditVm
        {
            UserId = user.UserId,
            PersonId = user.Person.PersonId,

            FullName = user.Person.FullName,
            Email = user.Person.Email ?? "",
            Phone = user.Person.Phone,

            IcOrPassport = user.Person.IcOrPassport,
            Gender = user.Person.Gender,
            DateOfBirth = user.Person.DateOfBirth,

            AddressLine = user.Person.AddressLine,
            City = user.Person.City,
            State = user.Person.State,
            PostalCode = user.Person.PostalCode,

            IsActive = user.IsActive,
            RoleId = currentRoleId
        };

        return View(vm);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(UserEditVm vm)
    {
        ViewBag.Roles = await GetRoleSelectListAsync();
        LoadGoogleMapsApiKey();

        if (!ModelState.IsValid)
        {
            return View(vm);
        }

        var user = await _db.Users
            .Include(u => u.Person)
            .FirstOrDefaultAsync(u => u.UserId == vm.UserId);

        if (user == null) return NotFound();
        if (user.Person == null) return BadRequest();

        var newEmail = vm.Email.Trim().ToLower();

        var emailExists = await _db.Users
            .Include(u => u.Person)
            .AnyAsync(u =>
                u.UserId != vm.UserId &&
                u.Person != null &&
                u.Person.Email != null &&
                u.Person.Email.ToLower() == newEmail);

        if (emailExists)
        {
            ModelState.AddModelError(nameof(vm.Email), "Email already exists.");
            return View(vm);
        }

        user.Person.FullName = vm.FullName.Trim();
        user.Person.Email = newEmail;
        user.Person.Phone = string.IsNullOrWhiteSpace(vm.Phone) ? null : vm.Phone.Trim();

        user.Person.IcOrPassport = string.IsNullOrWhiteSpace(vm.IcOrPassport) ? null : vm.IcOrPassport.Trim();
        user.Person.Gender = string.IsNullOrWhiteSpace(vm.Gender) ? null : vm.Gender.Trim();
        user.Person.DateOfBirth = vm.DateOfBirth;

        user.Person.AddressLine = string.IsNullOrWhiteSpace(vm.AddressLine) ? null : vm.AddressLine.Trim();
        user.Person.City = string.IsNullOrWhiteSpace(vm.City) ? null : vm.City.Trim();
        user.Person.State = string.IsNullOrWhiteSpace(vm.State) ? null : vm.State.Trim();
        user.Person.PostalCode = string.IsNullOrWhiteSpace(vm.PostalCode) ? null : vm.PostalCode.Trim();

        user.Person.UpdatedAt = DateTime.UtcNow;
        user.IsActive = vm.IsActive;

        if (!string.IsNullOrWhiteSpace(vm.NewPassword))
        {
            if (vm.NewPassword.Length < 6)
            {
                ModelState.AddModelError(nameof(vm.NewPassword), "Password must be at least 6 characters.");
                return View(vm);
            }

            user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(vm.NewPassword);
        }

        var existingRoles = await _db.UserRoles
            .Where(ur => ur.UserId == vm.UserId)
            .ToListAsync();

        if (existingRoles.Count > 0)
        {
            _db.UserRoles.RemoveRange(existingRoles);
        }

        _db.UserRoles.Add(new UserRole
        {
            UserId = vm.UserId,
            RoleId = vm.RoleId
        });

        await _db.SaveChangesAsync();

        TempData["Success"] = "User account updated successfully.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Deactivate(long id)
    {
        var user = await _db.Users
            .Include(u => u.Person)
            .FirstOrDefaultAsync(u => u.UserId == id);

        if (user == null)
        {
            return NotFound();
        }

        user.IsActive = false;
        await _db.SaveChangesAsync();

        TempData["Success"] = $"User '{user.Person?.FullName ?? user.UserId.ToString()}' has been deactivated.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Reactivate(long id)
    {
        var user = await _db.Users
            .Include(u => u.Person)
            .FirstOrDefaultAsync(u => u.UserId == id);

        if (user == null)
        {
            return NotFound();
        }

        user.IsActive = true;
        await _db.SaveChangesAsync();

        TempData["Success"] = $"User '{user.Person?.FullName ?? user.UserId.ToString()}' has been reactivated.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Delete(long id)
    {
        var user = await _db.Users
            .Include(u => u.Person)
            .FirstOrDefaultAsync(u => u.UserId == id);
        if (user == null) return NotFound();
        return View(user);
    }

    private void LoadGoogleMapsApiKey()
    {
        ViewBag.GoogleMapsApiKey = _configuration["GoogleMaps:ApiKey"]
            ?? Environment.GetEnvironmentVariable("GOOGLE_MAPS_API_KEY");
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(long id)
    {
        var user = await _db.Users
            .Include(u => u.Person)
            .FirstOrDefaultAsync(u => u.UserId == id);
        if (user == null) return NotFound();

        // remove role links first
        var roles = await _db.UserRoles.Where(ur => ur.UserId == id).ToListAsync();
        if (roles.Count > 0) _db.UserRoles.RemoveRange(roles);

        _db.Users.Remove(user);
        await _db.SaveChangesAsync();

        if (user.Person != null)
        {
            var personId = user.Person.PersonId;
            var stillReferenced = await _db.Beneficiaries.AnyAsync(b => b.PersonId == personId)
                || await _db.PersonRelationships.AnyAsync(r => r.MainPersonId == personId || r.RelatedPersonId == personId);

            if (!stillReferenced)
            {
                _db.Persons.Remove(user.Person);
                await _db.SaveChangesAsync();
            }
        }

        return RedirectToAction(nameof(Index));
    }
}
