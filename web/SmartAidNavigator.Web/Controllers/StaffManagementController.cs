using BCrypt.Net;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.Models;
using SmartAidNavigator.Web.ViewModels;

namespace SmartAidNavigator.Web.Controllers;

public class StaffManagementController : Controller
{
    private readonly AppDbContext _db;
    private readonly IConfiguration _configuration;

    public StaffManagementController(AppDbContext db, IConfiguration configuration)
    {
        _db = db;
        _configuration = configuration;
    }

    // =========================
    // ADMIN: ALL NGO STAFF
    // =========================
    [RequireRole("ADMIN")]
    public async Task<IActionResult> AdminNgoStaff()
    {
        var currentUserId = CurrentUserHelper.GetUserId(HttpContext);

        var rows = await (
            from ns in _db.NgoStaff
            join u in _db.Users on ns.UserId equals u.UserId
            join p in _db.Persons on u.PersonId equals p.PersonId
            join n in _db.Ngos on ns.NgoId equals n.NgoId
            orderby n.NgoName, p.FullName
            select new StaffManagementRowVm
            {
                UserId = u.UserId,
                EntityId = n.NgoId,
                FullName = p.FullName,
                Email = p.Email ?? "-",
                Phone = p.Phone,
                EntityName = n.NgoName,
                StaffTitle = ns.StaffTitle ?? "-",
                IsActive = u.IsActive,
                IsSelf = u.UserId == currentUserId
            }
        ).ToListAsync();

        return View("Index", new StaffManagementIndexVm
        {
            PageTitle = "Manage All NGO Staff",
            PageSubtitle = "Admin can manage staff accounts linked to all NGOs.",
            BackAction = nameof(AdminNgoStaff),
            CreateAction = nameof(CreateAdminNgoStaff),
            DeactivateAction = nameof(AdminDeactivateUser),
            ReactivateAction = nameof(AdminReactivateUser),
            RemoveAction = nameof(AdminRemoveNgoStaff),
            Rows = rows
        });
    }

    [HttpGet]
    [RequireRole("ADMIN")]
    public async Task<IActionResult> CreateAdminNgoStaff()
    {
        LoadGoogleMapsApiKey();

        var vm = new StaffCreateVm
        {
            PageTitle = "Create NGO Staff",
            BackAction = nameof(AdminNgoStaff),
            PostAction = nameof(CreateAdminNgoStaff),
            StaffType = "NGO Staff",
            IsActive = true,
            StaffTitle = "Staff",
            NgoOptions = await GetNgoSelectListAsync()
        };

        return View("Create", vm);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireRole("ADMIN")]
    public async Task<IActionResult> CreateAdminNgoStaff(StaffCreateVm vm)
    {
        LoadGoogleMapsApiKey();

        vm.PageTitle = "Create NGO Staff";
        vm.BackAction = nameof(AdminNgoStaff);
        vm.PostAction = nameof(CreateAdminNgoStaff);
        vm.StaffType = "NGO Staff";
        vm.NgoOptions = await GetNgoSelectListAsync(vm.NgoId);

        if (!ModelState.IsValid)
        {
            return View("Create", vm);
        }

        if (!vm.NgoId.HasValue || vm.NgoId.Value <= 0)
        {
            ModelState.AddModelError(nameof(vm.NgoId), "Please select an NGO.");
            return View("Create", vm);
        }

        if (!IsValidStaffTitle(vm.StaffType, vm.StaffTitle))
        {
            ModelState.AddModelError(nameof(vm.StaffTitle), "Please select either Owner or Staff.");
            return View("Create", vm);
        }

        var ngo = await _db.Ngos.FirstOrDefaultAsync(x => x.NgoId == vm.NgoId.Value);

        if (ngo == null)
        {
            ModelState.AddModelError(nameof(vm.NgoId), "Selected NGO was not found.");
            return View("Create", vm);
        }

        var email = vm.Email.Trim().ToLower();

        var emailExists = await _db.Persons
            .AnyAsync(x => x.Email != null && x.Email.ToLower() == email);

        if (emailExists)
        {
            ModelState.AddModelError(nameof(vm.Email), "This email is already used by another account.");
            return View("Create", vm);
        }

        var ngoStaffRoleId = await _db.Roles
            .Where(x => x.RoleName == "NGO_STAFF")
            .Select(x => (int?)x.RoleId)
            .FirstOrDefaultAsync();

        if (!ngoStaffRoleId.HasValue)
        {
            ModelState.AddModelError("", "NGO_STAFF role was not found in the roles table.");
            return View("Create", vm);
        }

        using var tx = await _db.Database.BeginTransactionAsync();

        try
        {
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
                RoleId = ngoStaffRoleId.Value
            });

            _db.NgoStaff.Add(new NgoStaff
            {
                NgoId = vm.NgoId.Value,
                UserId = user.UserId,
                StaffTitle = vm.StaffTitle!.Trim()
            });

            await _db.SaveChangesAsync();
            await tx.CommitAsync();

            TempData["Success"] = $"NGO staff '{person.FullName}' has been created successfully.";
            return RedirectToAction(nameof(AdminNgoStaff));
        }
        catch
        {
            await tx.RollbackAsync();

            ModelState.AddModelError("", "Failed to create NGO staff. Please try again.");
            return View("Create", vm);
        }
    }

    // =========================
    // ADMIN: ALL SHELTER MANAGERS
    // =========================
    [RequireRole("ADMIN")]
    public async Task<IActionResult> AdminShelterManagers()
    {
        var currentUserId = CurrentUserHelper.GetUserId(HttpContext);

        var rows = await (
            from sm in _db.ShelterManagers
            join u in _db.Users on sm.UserId equals u.UserId
            join p in _db.Persons on u.PersonId equals p.PersonId
            join s in _db.Shelters on sm.ShelterId equals s.ShelterId
            orderby s.ShelterName, p.FullName
            select new StaffManagementRowVm
            {
                UserId = u.UserId,
                EntityId = s.ShelterId,
                FullName = p.FullName,
                Email = p.Email ?? "-",
                Phone = p.Phone,
                EntityName = s.ShelterName,
                StaffTitle = sm.StaffTitle ?? "Shelter Manager",
                IsActive = u.IsActive,
                IsSelf = u.UserId == currentUserId
            }
        ).ToListAsync();

        return View("Index", new StaffManagementIndexVm
        {
            PageTitle = "Manage All Shelter Managers",
            PageSubtitle = "Admin can manage manager accounts linked to all shelters.",
            BackAction = nameof(AdminShelterManagers),
            CreateAction = nameof(CreateAdminShelterManager),
            DeactivateAction = nameof(AdminDeactivateUser),
            ReactivateAction = nameof(AdminReactivateUser),
            RemoveAction = nameof(AdminRemoveShelterManager),
            Rows = rows
        });
    }

    [HttpGet]
    [RequireRole("ADMIN")]
    public async Task<IActionResult> CreateAdminShelterManager()
    {
        LoadGoogleMapsApiKey();

        var vm = new StaffCreateVm
        {
            PageTitle = "Create Shelter Staff",
            PostAction = nameof(CreateAdminShelterManager),
            BackAction = nameof(AdminShelterManagers),
            StaffType = "Shelter Manager",
            StaffTitle = "Shelter Staff",
            IsActive = true
        };

        await LoadShelterOptionsAsync(vm);

        return View("Create", vm);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireRole("ADMIN")]
    public async Task<IActionResult> CreateAdminShelterManager(StaffCreateVm vm)
    {
        LoadGoogleMapsApiKey();

        vm.PageTitle = "Create Shelter Manager";
        vm.PostAction = nameof(CreateAdminShelterManager);
        vm.BackAction = nameof(AdminShelterManagers);
        vm.StaffType = "Shelter Manager";
        await LoadShelterOptionsAsync(vm);

        if (!vm.ShelterId.HasValue)
        {
            ModelState.AddModelError(nameof(vm.ShelterId), "Please select a shelter.");
        }

        if (!IsValidStaffTitle(vm.StaffType, vm.StaffTitle))
        {
            ModelState.AddModelError(nameof(vm.StaffTitle), "Please select either Shelter Manager or Shelter Staff.");
        }

        if (!ModelState.IsValid)
        {
            return View("Create", vm);
        }

        var result = await CreateUserWithRoleAsync(
            vm,
            roleName: "SHELTER_MANAGER",
            staffTitle: vm.StaffTitle ?? "Shelter Staff"
        );

        if (!result.Ok)
        {
            ModelState.AddModelError("", result.Error);
            return View("Create", vm);
        }

        _db.ShelterManagers.Add(new ShelterManager
        {
            ShelterId = vm.ShelterId!.Value,
            UserId = result.UserId,
            StaffTitle = vm.StaffTitle!.Trim()
        });

        await _db.SaveChangesAsync();

        TempData["Success"] = "Shelter manager account created successfully.";
        return RedirectToAction(nameof(AdminShelterManagers));
    }

    // =========================
    // NGO OWNER: MY NGO STAFF
    // =========================
    [RequireRole("NGO_STAFF")]
    public async Task<IActionResult> MyNgoStaff()
    {
        var currentUserId = CurrentUserHelper.GetUserId(HttpContext);
        var ownerStaff = await GetMyNgoOwnerStaffAsync(currentUserId);

        if (ownerStaff == null)
        {
            TempData["Error"] = "Only the NGO owner/main contact can manage NGO staff.";
            return RedirectToAction("Dashboard", "NgoStaff");
        }

        var rows = await (
            from ns in _db.NgoStaff
            join u in _db.Users on ns.UserId equals u.UserId
            join p in _db.Persons on u.PersonId equals p.PersonId
            join n in _db.Ngos on ns.NgoId equals n.NgoId
            where ns.NgoId == ownerStaff.NgoId
            orderby p.FullName
            select new StaffManagementRowVm
            {
                UserId = u.UserId,
                EntityId = n.NgoId,
                FullName = p.FullName,
                Email = p.Email ?? "-",
                Phone = p.Phone,
                EntityName = n.NgoName,
                StaffTitle = ns.StaffTitle ?? "-",
                IsActive = u.IsActive,
                IsSelf = u.UserId == currentUserId
            }
        ).ToListAsync();

        return View("Index", new StaffManagementIndexVm
        {
            PageTitle = "Manage My NGO Staff",
            PageSubtitle = "Manage staff accounts under your own NGO only.",
            BackAction = nameof(MyNgoStaff),
            CreateAction = nameof(CreateMyNgoStaff),
            DeactivateAction = nameof(MyNgoDeactivateUser),
            ReactivateAction = nameof(MyNgoReactivateUser),
            RemoveAction = nameof(MyNgoRemoveStaff),
            Rows = rows
        });
    }

    [HttpGet]
    [RequireRole("NGO_STAFF")]
    public async Task<IActionResult> CreateMyNgoStaff()
    {
        LoadGoogleMapsApiKey();

        var currentUserId = CurrentUserHelper.GetUserId(HttpContext);
        var ownerStaff = await GetMyNgoOwnerStaffAsync(currentUserId);

        if (ownerStaff == null)
        {
            TempData["Error"] = "Only the NGO owner/main contact can create NGO staff.";
            return RedirectToAction(nameof(MyNgoStaff));
        }

        var ngo = await _db.Ngos
            .FirstOrDefaultAsync(x => x.NgoId == ownerStaff.NgoId);

        var vm = new StaffCreateVm
        {
            PageTitle = "Create My NGO Staff",
            PostAction = nameof(CreateMyNgoStaff),
            BackAction = nameof(MyNgoStaff),
            StaffType = "NGO Staff",
            NgoId = ownerStaff.NgoId,
            StaffTitle = "Staff",
            IsActive = true,
            NgoOptions = new List<SelectListItem>
            {
                new SelectListItem
                {
                    Value = ownerStaff.NgoId.ToString(),
                    Text = ngo?.NgoName ?? "My NGO",
                    Selected = true
                }
            }
        };

        return View("Create", vm);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireRole("NGO_STAFF")]
    public async Task<IActionResult> CreateMyNgoStaff(StaffCreateVm vm)
    {
        LoadGoogleMapsApiKey();

        var currentUserId = CurrentUserHelper.GetUserId(HttpContext);
        var ownerStaff = await GetMyNgoOwnerStaffAsync(currentUserId);

        if (ownerStaff == null)
        {
            TempData["Error"] = "Only the NGO owner/main contact can create NGO staff.";
            return RedirectToAction(nameof(MyNgoStaff));
        }

        vm.PageTitle = "Create My NGO Staff";
        vm.PostAction = nameof(CreateMyNgoStaff);
        vm.BackAction = nameof(MyNgoStaff);
        vm.StaffType = "NGO Staff";
        vm.NgoId = ownerStaff.NgoId;

        var ngo = await _db.Ngos
            .FirstOrDefaultAsync(x => x.NgoId == ownerStaff.NgoId);

        vm.NgoOptions = new List<SelectListItem>
        {
            new SelectListItem
            {
                Value = ownerStaff.NgoId.ToString(),
                Text = ngo?.NgoName ?? "My NGO",
                Selected = true
            }
        };

        if (!IsValidStaffTitle(vm.StaffType, vm.StaffTitle))
        {
            ModelState.AddModelError(nameof(vm.StaffTitle), "Please select either Owner or Staff.");
        }

        if (!ModelState.IsValid)
        {
            return View("Create", vm);
        }

        var result = await CreateUserWithRoleAsync(
            vm,
            roleName: "NGO_STAFF",
            staffTitle: vm.StaffTitle ?? "Staff"
        );

        if (!result.Ok)
        {
            ModelState.AddModelError("", result.Error);
            return View("Create", vm);
        }

        _db.NgoStaff.Add(new NgoStaff
        {
            NgoId = ownerStaff.NgoId,
            UserId = result.UserId,
            StaffTitle = vm.StaffTitle!.Trim()
        });

        await _db.SaveChangesAsync();

        TempData["Success"] = "NGO staff account created successfully.";
        return RedirectToAction(nameof(MyNgoStaff));
    }

    // =========================
    // SHELTER MANAGER: MY SHELTER MANAGERS
    // =========================
    [RequireRole("SHELTER_MANAGER")]
    public async Task<IActionResult> MyShelterManagers()
    {
        var currentUserId = CurrentUserHelper.GetUserId(HttpContext);

        var myShelter = await _db.ShelterManagers
            .FirstOrDefaultAsync(x => x.UserId == currentUserId);

        if (myShelter == null)
        {
            TempData["Error"] = "Your account is not linked to any shelter.";
            return RedirectToAction("Dashboard", "ShelterManager");
        }

        var rows = await (
            from sm in _db.ShelterManagers
            join u in _db.Users on sm.UserId equals u.UserId
            join p in _db.Persons on u.PersonId equals p.PersonId
            join s in _db.Shelters on sm.ShelterId equals s.ShelterId
            where sm.ShelterId == myShelter.ShelterId
            orderby p.FullName
            select new StaffManagementRowVm
            {
                UserId = u.UserId,
                EntityId = s.ShelterId,
                FullName = p.FullName,
                Email = p.Email ?? "-",
                Phone = p.Phone,
                EntityName = s.ShelterName,
                StaffTitle = sm.StaffTitle ?? "Shelter Manager",
                IsActive = u.IsActive,
                IsSelf = u.UserId == currentUserId
            }
        ).ToListAsync();

        return View("Index", new StaffManagementIndexVm
        {
            PageTitle = "Manage My Shelter Managers",
            PageSubtitle = "Manage manager accounts under your own shelter only.",
            BackAction = nameof(MyShelterManagers),
            CreateAction = nameof(CreateMyShelterManager),
            DeactivateAction = nameof(MyShelterDeactivateUser),
            ReactivateAction = nameof(MyShelterReactivateUser),
            RemoveAction = nameof(MyShelterRemoveManager),
            Rows = rows
        });
    }

    [HttpGet]
    [RequireRole("SHELTER_MANAGER")]
    public async Task<IActionResult> CreateMyShelterManager()
    {
        LoadGoogleMapsApiKey();

        var currentUserId = CurrentUserHelper.GetUserId(HttpContext);

        var myShelter = await _db.ShelterManagers
            .FirstOrDefaultAsync(x => x.UserId == currentUserId);

        if (myShelter == null)
        {
            TempData["Error"] = "Your account is not linked to any shelter.";
            return RedirectToAction(nameof(MyShelterManagers));
        }

        var shelter = await _db.Shelters
            .Include(x => x.Ngo)
            .FirstOrDefaultAsync(x => x.ShelterId == myShelter.ShelterId);

        var vm = new StaffCreateVm
        {
            PageTitle = "Create Shelter Staff",
            PostAction = nameof(CreateMyShelterManager),
            BackAction = nameof(MyShelterManagers),
            StaffType = "Shelter Manager",
            StaffTitle = "Shelter Staff",
            ShelterId = myShelter.ShelterId,
            IsActive = true,
            ShelterOptions = new List<SelectListItem>
            {
                new SelectListItem
                {
                    Value = myShelter.ShelterId.ToString(),
                    Text = shelter?.Ngo != null
                        ? $"{shelter.ShelterName} - {shelter.Ngo.NgoName}"
                        : shelter?.ShelterName ?? "My Shelter",
                    Selected = true
                }
            }
        };

        return View("Create", vm);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireRole("SHELTER_MANAGER")]
    public async Task<IActionResult> CreateMyShelterManager(StaffCreateVm vm)
    {
        LoadGoogleMapsApiKey();

        var currentUserId = CurrentUserHelper.GetUserId(HttpContext);

        var myShelter = await _db.ShelterManagers
            .FirstOrDefaultAsync(x => x.UserId == currentUserId);

        if (myShelter == null)
        {
            TempData["Error"] = "Your account is not linked to any shelter.";
            return RedirectToAction(nameof(MyShelterManagers));
        }

        vm.PageTitle = "Create Shelter Manager";
        vm.PostAction = nameof(CreateMyShelterManager);
        vm.BackAction = nameof(MyShelterManagers);
        vm.StaffType = "Shelter Manager";
        vm.ShelterId = myShelter.ShelterId;

        var shelter = await _db.Shelters
            .Include(x => x.Ngo)
            .FirstOrDefaultAsync(x => x.ShelterId == myShelter.ShelterId);

        vm.ShelterOptions = new List<SelectListItem>
        {
            new SelectListItem
            {
                Value = myShelter.ShelterId.ToString(),
                Text = shelter?.Ngo != null
                    ? $"{shelter.ShelterName} - {shelter.Ngo.NgoName}"
                    : shelter?.ShelterName ?? "My Shelter",
                Selected = true
            }
        };

        if (!IsValidStaffTitle(vm.StaffType, vm.StaffTitle))
        {
            ModelState.AddModelError(nameof(vm.StaffTitle), "Please select either Shelter Manager or Shelter Staff.");
        }

        if (!ModelState.IsValid)
        {
            return View("Create", vm);
        }

        var result = await CreateUserWithRoleAsync(
            vm,
            roleName: "SHELTER_MANAGER",
            staffTitle: vm.StaffTitle ?? "Shelter Staff"
        );

        if (!result.Ok)
        {
            ModelState.AddModelError("", result.Error);
            return View("Create", vm);
        }

        _db.ShelterManagers.Add(new ShelterManager
        {
            ShelterId = myShelter.ShelterId,
            UserId = result.UserId,
            StaffTitle = vm.StaffTitle!.Trim()
        });

        await _db.SaveChangesAsync();

        TempData["Success"] = "Shelter manager account created successfully.";
        return RedirectToAction(nameof(MyShelterManagers));
    }

    // =========================
    // ADMIN ACTIONS
    // =========================
    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireRole("ADMIN")]
    public async Task<IActionResult> AdminDeactivateUser(long userId)
    {
        await SetUserActiveAsync(userId, false);
        TempData["Success"] = "Staff account deactivated.";
        return RedirectBackFromStaffAction();
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireRole("ADMIN")]
    public async Task<IActionResult> AdminReactivateUser(long userId)
    {
        await SetUserActiveAsync(userId, true);
        TempData["Success"] = "Staff account reactivated.";
        return RedirectBackFromStaffAction();
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireRole("ADMIN")]
    public async Task<IActionResult> AdminRemoveNgoStaff(long userId, long entityId)
    {
        var link = await _db.NgoStaff
            .FirstOrDefaultAsync(x => x.UserId == userId && x.NgoId == entityId);

        if (link != null)
        {
            _db.NgoStaff.Remove(link);
            await _db.SaveChangesAsync();
            TempData["Success"] = "NGO staff link removed.";
        }

        return RedirectToAction(nameof(AdminNgoStaff));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireRole("ADMIN")]
    public async Task<IActionResult> AdminRemoveShelterManager(long userId, long entityId)
    {
        var link = await _db.ShelterManagers
            .FirstOrDefaultAsync(x => x.UserId == userId && x.ShelterId == entityId);

        if (link != null)
        {
            _db.ShelterManagers.Remove(link);
            await _db.SaveChangesAsync();
            TempData["Success"] = "Shelter manager link removed.";
        }

        return RedirectToAction(nameof(AdminShelterManagers));
    }

    // =========================
    // MY NGO ACTIONS
    // =========================
    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireRole("NGO_STAFF")]
    public async Task<IActionResult> MyNgoDeactivateUser(long userId)
    {
        var currentUserId = CurrentUserHelper.GetUserId(HttpContext);

        if (userId == currentUserId)
        {
            TempData["Error"] = "You cannot deactivate your own account.";
            return RedirectToAction(nameof(MyNgoStaff));
        }

        var ownerStaff = await GetMyNgoOwnerStaffAsync(currentUserId);
        if (ownerStaff == null)
        {
            return Forbid();
        }

        var belongsToMyNgo = await _db.NgoStaff
            .AnyAsync(x => x.NgoId == ownerStaff.NgoId && x.UserId == userId);

        if (!belongsToMyNgo)
        {
            return Forbid();
        }

        await SetUserActiveAsync(userId, false);
        TempData["Success"] = "NGO staff account deactivated.";
        return RedirectToAction(nameof(MyNgoStaff));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireRole("NGO_STAFF")]
    public async Task<IActionResult> MyNgoReactivateUser(long userId)
    {
        var currentUserId = CurrentUserHelper.GetUserId(HttpContext);

        var ownerStaff = await GetMyNgoOwnerStaffAsync(currentUserId);
        if (ownerStaff == null)
        {
            return Forbid();
        }

        var belongsToMyNgo = await _db.NgoStaff
            .AnyAsync(x => x.NgoId == ownerStaff.NgoId && x.UserId == userId);

        if (!belongsToMyNgo)
        {
            return Forbid();
        }

        await SetUserActiveAsync(userId, true);
        TempData["Success"] = "NGO staff account reactivated.";
        return RedirectToAction(nameof(MyNgoStaff));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireRole("NGO_STAFF")]
    public async Task<IActionResult> MyNgoRemoveStaff(long userId, long entityId)
    {
        var currentUserId = CurrentUserHelper.GetUserId(HttpContext);

        if (userId == currentUserId)
        {
            TempData["Error"] = "You cannot remove yourself from your NGO.";
            return RedirectToAction(nameof(MyNgoStaff));
        }

        var ownerStaff = await GetMyNgoOwnerStaffAsync(currentUserId);
        if (ownerStaff == null || ownerStaff.NgoId != entityId)
        {
            return Forbid();
        }

        var link = await _db.NgoStaff
            .FirstOrDefaultAsync(x => x.UserId == userId && x.NgoId == entityId);

        if (link != null)
        {
            _db.NgoStaff.Remove(link);
            await _db.SaveChangesAsync();
            TempData["Success"] = "NGO staff link removed.";
        }

        return RedirectToAction(nameof(MyNgoStaff));
    }

    // =========================
    // MY SHELTER ACTIONS
    // =========================
    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireRole("SHELTER_MANAGER")]
    public async Task<IActionResult> MyShelterDeactivateUser(long userId)
    {
        var currentUserId = CurrentUserHelper.GetUserId(HttpContext);

        if (userId == currentUserId)
        {
            TempData["Error"] = "You cannot deactivate your own account.";
            return RedirectToAction(nameof(MyShelterManagers));
        }

        var myShelter = await _db.ShelterManagers
            .FirstOrDefaultAsync(x => x.UserId == currentUserId);

        if (myShelter == null)
        {
            return Forbid();
        }

        var belongsToMyShelter = await _db.ShelterManagers
            .AnyAsync(x => x.ShelterId == myShelter.ShelterId && x.UserId == userId);

        if (!belongsToMyShelter)
        {
            return Forbid();
        }

        await SetUserActiveAsync(userId, false);
        TempData["Success"] = "Shelter manager account deactivated.";
        return RedirectToAction(nameof(MyShelterManagers));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireRole("SHELTER_MANAGER")]
    public async Task<IActionResult> MyShelterReactivateUser(long userId)
    {
        var currentUserId = CurrentUserHelper.GetUserId(HttpContext);

        var myShelter = await _db.ShelterManagers
            .FirstOrDefaultAsync(x => x.UserId == currentUserId);

        if (myShelter == null)
        {
            return Forbid();
        }

        var belongsToMyShelter = await _db.ShelterManagers
            .AnyAsync(x => x.ShelterId == myShelter.ShelterId && x.UserId == userId);

        if (!belongsToMyShelter)
        {
            return Forbid();
        }

        await SetUserActiveAsync(userId, true);
        TempData["Success"] = "Shelter manager account reactivated.";
        return RedirectToAction(nameof(MyShelterManagers));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireRole("SHELTER_MANAGER")]
    public async Task<IActionResult> MyShelterRemoveManager(long userId, long entityId)
    {
        var currentUserId = CurrentUserHelper.GetUserId(HttpContext);

        if (userId == currentUserId)
        {
            TempData["Error"] = "You cannot remove yourself from your shelter.";
            return RedirectToAction(nameof(MyShelterManagers));
        }

        var myShelter = await _db.ShelterManagers
            .FirstOrDefaultAsync(x => x.UserId == currentUserId);

        if (myShelter == null || myShelter.ShelterId != entityId)
        {
            return Forbid();
        }

        var link = await _db.ShelterManagers
            .FirstOrDefaultAsync(x => x.UserId == userId && x.ShelterId == entityId);

        if (link != null)
        {
            _db.ShelterManagers.Remove(link);
            await _db.SaveChangesAsync();
            TempData["Success"] = "Shelter manager link removed.";
        }

        return RedirectToAction(nameof(MyShelterManagers));
    }

    [HttpGet]
    public async Task<IActionResult> Details(long userId, string? from = null)
    {
        var currentUserId = CurrentUserHelper.GetUserId(HttpContext);
        var roles = HttpContext.Session.GetString(SessionKeys.Roles) ?? "";

        if (currentUserId <= 0 || string.IsNullOrWhiteSpace(roles))
        {
            return RedirectToAction("Login", "Account");
        }

        var isAdmin = roles.Contains("ADMIN");
        var isNgo = roles.Contains("NGO_STAFF");
        var isShelterMgr = roles.Contains("SHELTER_MANAGER");

        if (!isAdmin && !isNgo && !isShelterMgr)
        {
            return Forbid();
        }

        var user = await _db.Users
            .Include(x => x.Person)
            .FirstOrDefaultAsync(x => x.UserId == userId);

        if (user == null || user.Person == null)
        {
            return NotFound();
        }

        var userRoles = await (
            from ur in _db.UserRoles
            join r in _db.Roles on ur.RoleId equals r.RoleId
            where ur.UserId == userId
            select r.RoleName
        ).ToListAsync();

        var vm = new StaffDetailsVm
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
            RolesCsv = string.Join(", ", userRoles),
            BackAction = string.IsNullOrWhiteSpace(from) ? nameof(AdminNgoStaff) : from
        };

        var ngoStaff = await (
            from ns in _db.NgoStaff
            join n in _db.Ngos on ns.NgoId equals n.NgoId
            where ns.UserId == userId
            select new
            {
                ns.NgoId,
                n.NgoName,
                ns.StaffTitle
            }
        ).FirstOrDefaultAsync();

        var shelterManager = await (
            from sm in _db.ShelterManagers
            join s in _db.Shelters on sm.ShelterId equals s.ShelterId
            where sm.UserId == userId
            select new
            {
                sm.ShelterId,
                s.ShelterName,
                sm.StaffTitle
            }
        ).FirstOrDefaultAsync();

        if (ngoStaff != null)
        {
            vm.StaffType = "NGO Staff";
            vm.StaffTitle = ngoStaff.StaffTitle ?? "-";
            vm.LinkedUnitType = "NGO";
            vm.LinkedUnitName = ngoStaff.NgoName;
            vm.LinkedUnitId = ngoStaff.NgoId;
        }
        else if (shelterManager != null)
        {
            vm.StaffType = "Shelter Manager";
            vm.StaffTitle = shelterManager.StaffTitle ?? "Shelter Manager";
            vm.LinkedUnitType = "Shelter";
            vm.LinkedUnitName = shelterManager.ShelterName;
            vm.LinkedUnitId = shelterManager.ShelterId;
        }
        else
        {
            vm.StaffType = "User Account";
            vm.StaffTitle = "-";
            vm.LinkedUnitType = "-";
            vm.LinkedUnitName = "-";
        }

        // ADMIN can view any staff details
        if (isAdmin)
        {
            return View(vm);
        }

        // NGO owner/main staff can only view staff under their own NGO
        if (isNgo)
        {
            var ownerStaff = await GetMyNgoOwnerStaffAsync(currentUserId);

            if (ownerStaff == null)
            {
                return Forbid();
            }

            var belongsToMyNgo = await _db.NgoStaff
                .AnyAsync(x => x.UserId == userId && x.NgoId == ownerStaff.NgoId);

            if (!belongsToMyNgo)
            {
                return Forbid();
            }

            vm.BackAction = nameof(MyNgoStaff);
            return View(vm);
        }

        // Shelter manager can only view staff under their own shelter
        if (isShelterMgr)
        {
            var myShelter = await _db.ShelterManagers
                .FirstOrDefaultAsync(x => x.UserId == currentUserId);

            if (myShelter == null)
            {
                return Forbid();
            }

            var belongsToMyShelter = await _db.ShelterManagers
                .AnyAsync(x => x.UserId == userId && x.ShelterId == myShelter.ShelterId);

            if (!belongsToMyShelter)
            {
                return Forbid();
            }

            vm.BackAction = nameof(MyShelterManagers);
            return View(vm);
        }

        return Forbid();
    }

    [HttpGet]
    public async Task<IActionResult> Edit(long userId, string? from = null)
    {
        var currentUserId = CurrentUserHelper.GetUserId(HttpContext);
        var roles = HttpContext.Session.GetString(SessionKeys.Roles) ?? "";

        if (currentUserId <= 0 || string.IsNullOrWhiteSpace(roles))
        {
            return RedirectToAction("Login", "Account");
        }

        var access = await CanManageStaffAsync(currentUserId, userId, roles);

        if (!access.Allowed)
        {
            return Forbid();
        }

        var user = await _db.Users
            .Include(x => x.Person)
            .FirstOrDefaultAsync(x => x.UserId == userId);

        if (user == null || user.Person == null)
        {
            return NotFound();
        }

        var ngoStaff = await (
            from ns in _db.NgoStaff
            join n in _db.Ngos on ns.NgoId equals n.NgoId
            where ns.UserId == userId
            select new
            {
                ns.StaffTitle,
                n.NgoName
            }
        ).FirstOrDefaultAsync();

        var shelterManager = await (
            from sm in _db.ShelterManagers
            join s in _db.Shelters on sm.ShelterId equals s.ShelterId
            where sm.UserId == userId
            select new
            {
                s.ShelterName,
                sm.StaffTitle
            }
        ).FirstOrDefaultAsync();

        var vm = new StaffEditVm
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

            StaffTitle = ngoStaff?.StaffTitle ?? shelterManager?.StaffTitle ?? "Shelter Manager",
            IsNgoStaff = ngoStaff != null,
            StaffType = ngoStaff != null ? "NGO Staff" : "Shelter Manager",
            LinkedUnitName = ngoStaff?.NgoName ?? shelterManager?.ShelterName ?? "-",
            BackAction = string.IsNullOrWhiteSpace(from) ? access.BackAction : from,
            PageTitle = ngoStaff != null ? "Edit NGO Staff" : "Edit Shelter Staff"
        };

        LoadGoogleMapsApiKey();

        return View(vm);

    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(StaffEditVm vm)
    {
        var currentUserId = CurrentUserHelper.GetUserId(HttpContext);
        var roles = HttpContext.Session.GetString(SessionKeys.Roles) ?? "";

        if (currentUserId <= 0 || string.IsNullOrWhiteSpace(roles))
        {
            return RedirectToAction("Login", "Account");
        }

        var access = await CanManageStaffAsync(currentUserId, vm.UserId, roles);

        if (!access.Allowed)
        {
            return Forbid();
        }

        vm.BackAction = string.IsNullOrWhiteSpace(vm.BackAction) ? access.BackAction : vm.BackAction;

        var user = await _db.Users
            .Include(x => x.Person)
            .FirstOrDefaultAsync(x => x.UserId == vm.UserId);

        if (user == null || user.Person == null)
        {
            return NotFound();
        }

        var ngoStaff = await _db.NgoStaff
            .FirstOrDefaultAsync(x => x.UserId == vm.UserId);

        var shelterManager = await _db.ShelterManagers
            .FirstOrDefaultAsync(x => x.UserId == vm.UserId);

        vm.IsNgoStaff = ngoStaff != null;
        vm.StaffType = ngoStaff != null ? "NGO Staff" : "Shelter Manager";
        vm.PageTitle = ngoStaff != null ? "Edit NGO Staff" : "Edit Shelter Staff";

        if (!IsValidStaffTitle(vm.StaffType, vm.StaffTitle))
        {
            ModelState.AddModelError(
                nameof(vm.StaffTitle),
                vm.IsNgoStaff
                    ? "Please select either Owner or Staff."
                    : "Please select either Shelter Manager or Shelter Staff."
            );
        }

        if (!ModelState.IsValid)
        {
            LoadGoogleMapsApiKey();

            return View(vm);
        }

        var email = vm.Email.Trim().ToLower();

        var emailExists = await _db.Persons
            .AnyAsync(x =>
                x.PersonId != user.PersonId &&
                x.Email != null &&
                x.Email.ToLower() == email);

        if (emailExists)
        {
            ModelState.AddModelError(nameof(vm.Email), "This email is already used by another account.");

            LoadGoogleMapsApiKey();

            return View(vm);
        }

        user.Person.FullName = vm.FullName.Trim();
        user.Person.Email = email;
        user.Person.Phone = string.IsNullOrWhiteSpace(vm.Phone) ? null : vm.Phone.Trim();

        user.Person.IcOrPassport = string.IsNullOrWhiteSpace(vm.IcOrPassport) ? null : vm.IcOrPassport.Trim();
        user.Person.Gender = string.IsNullOrWhiteSpace(vm.Gender) ? null : vm.Gender.Trim();
        user.Person.DateOfBirth = vm.DateOfBirth;
        user.Person.AddressLine = string.IsNullOrWhiteSpace(vm.AddressLine) ? null : vm.AddressLine.Trim();
        user.Person.City = string.IsNullOrWhiteSpace(vm.City) ? null : vm.City.Trim();
        user.Person.State = string.IsNullOrWhiteSpace(vm.State) ? null : vm.State.Trim();
        user.Person.PostalCode = string.IsNullOrWhiteSpace(vm.PostalCode) ? null : vm.PostalCode.Trim();

        user.IsActive = vm.IsActive;
        user.Person.UpdatedAt = DateTime.UtcNow;

        if (!string.IsNullOrWhiteSpace(vm.NewPassword))
        {
            if (vm.NewPassword.Length < 6)
            {
                ModelState.AddModelError(nameof(vm.NewPassword), "Password must be at least 6 characters.");

                LoadGoogleMapsApiKey();

                return View(vm);
            }

            user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(vm.NewPassword);
        }

        if (ngoStaff != null)
        {
            ngoStaff.StaffTitle = vm.StaffTitle!.Trim();
        }

        if (shelterManager != null)
        {
            shelterManager.StaffTitle = vm.StaffTitle!.Trim();
        }

        await _db.SaveChangesAsync();

        TempData["Success"] = "Staff details updated successfully.";
        return RedirectToAction(vm.BackAction);
    }

    // =========================
    // HELPERS
    // =========================
    private static bool IsValidStaffTitle(string staffType, string? staffTitle)
    {
        staffType = (staffType ?? "").Trim();
        staffTitle = (staffTitle ?? "").Trim();

        if (staffType == "NGO Staff")
        {
            return staffTitle == "Owner" || staffTitle == "Staff";
        }

        if (staffType == "Shelter Manager")
        {
            return staffTitle == "Shelter Manager" || staffTitle == "Shelter Staff";
        }

        return false;
    }

    private static string GetDefaultStaffTitle(string staffType)
    {
        return staffType == "Shelter Manager"
            ? "Shelter Staff"
            : "Staff";
    }

    private void LoadGoogleMapsApiKey()
    {
        ViewBag.GoogleMapsApiKey = _configuration["GoogleMaps:ApiKey"]
            ?? Environment.GetEnvironmentVariable("GOOGLE_MAPS_API_KEY");
    }

    private async Task<(bool Ok, string Error, long UserId)> CreateUserWithRoleAsync(
        StaffCreateVm vm,
        string roleName,
        string staffTitle)
    {
        var email = vm.Email.Trim().ToLower();

        var emailExists = await _db.Persons
            .AnyAsync(x => x.Email != null && x.Email.ToLower() == email);

        if (emailExists)
        {
            return (false, "This email already exists.", 0);
        }

        var role = await _db.Roles.FirstOrDefaultAsync(x => x.RoleName == roleName);

        if (role == null)
        {
            return (false, $"Role '{roleName}' does not exist.", 0);
        }

        using var tx = await _db.Database.BeginTransactionAsync();

        try
        {
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
                RoleId = role.RoleId
            });

            await _db.SaveChangesAsync();
            await tx.CommitAsync();

            return (true, "", user.UserId);
        }
        catch
        {
            await tx.RollbackAsync();
            return (false, "Failed to create staff account.", 0);
        }
    }

    private async Task SetUserActiveAsync(long userId, bool active)
    {
        var user = await _db.Users.FirstOrDefaultAsync(x => x.UserId == userId);

        if (user != null)
        {
            user.IsActive = active;
            await _db.SaveChangesAsync();
        }
    }

    private async Task<NgoStaff?> GetMyNgoOwnerStaffAsync(long userId)
    {
        return await _db.NgoStaff
            .FirstOrDefaultAsync(x =>
                x.UserId == userId &&
                x.StaffTitle == "Owner");
    }

    private async Task<List<SelectListItem>> GetNgoSelectListAsync(long? selectedNgoId = null)
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

    private async Task LoadNgoOptionsAsync(StaffCreateVm vm)
    {
        vm.NgoOptions = await _db.Ngos
            .OrderBy(x => x.NgoName)
            .Select(x => new SelectListItem
            {
                Value = x.NgoId.ToString(),
                Text = x.NgoName
            })
            .ToListAsync();
    }

    private async Task LoadShelterOptionsAsync(StaffCreateVm vm)
    {
        vm.ShelterOptions = await _db.Shelters
            .Include(x => x.Ngo)
            .OrderBy(x => x.ShelterName)
            .Select(x => new SelectListItem
            {
                Value = x.ShelterId.ToString(),
                Text = x.Ngo != null
                    ? x.ShelterName + " - " + x.Ngo.NgoName
                    : x.ShelterName + " - No NGO",
                Selected = vm.ShelterId.HasValue && x.ShelterId == vm.ShelterId.Value
            })
            .ToListAsync();
    }

    private IActionResult RedirectBackFromStaffAction()
    {
        var referer = Request.Headers.Referer.ToString();

        if (referer.Contains(nameof(AdminShelterManagers), StringComparison.OrdinalIgnoreCase))
        {
            return RedirectToAction(nameof(AdminShelterManagers));
        }

        return RedirectToAction(nameof(AdminNgoStaff));
    }

    private async Task<(bool Allowed, string BackAction)> CanManageStaffAsync(
    long currentUserId,
    long targetUserId,
    string roles)
    {
        var isAdmin = roles.Contains("ADMIN");
        var isNgo = roles.Contains("NGO_STAFF");
        var isShelterMgr = roles.Contains("SHELTER_MANAGER");

        if (isAdmin)
        {
            var isNgoStaff = await _db.NgoStaff.AnyAsync(x => x.UserId == targetUserId);
            var isShelterManager = await _db.ShelterManagers.AnyAsync(x => x.UserId == targetUserId);

            if (isNgoStaff)
            {
                return (true, nameof(AdminNgoStaff));
            }

            if (isShelterManager)
            {
                return (true, nameof(AdminShelterManagers));
            }

            return (false, nameof(AdminNgoStaff));
        }

        if (isNgo)
        {
            var ownerStaff = await GetMyNgoOwnerStaffAsync(currentUserId);

            if (ownerStaff == null)
            {
                return (false, nameof(MyNgoStaff));
            }

            var belongsToMyNgo = await _db.NgoStaff
                .AnyAsync(x => x.UserId == targetUserId && x.NgoId == ownerStaff.NgoId);

            return (belongsToMyNgo, nameof(MyNgoStaff));
        }

        if (isShelterMgr)
        {
            var myShelter = await _db.ShelterManagers
                .FirstOrDefaultAsync(x => x.UserId == currentUserId);

            if (myShelter == null)
            {
                return (false, nameof(MyShelterManagers));
            }

            var belongsToMyShelter = await _db.ShelterManagers
                .AnyAsync(x => x.UserId == targetUserId && x.ShelterId == myShelter.ShelterId);

            return (belongsToMyShelter, nameof(MyShelterManagers));
        }

        return (false, "");
    }
}