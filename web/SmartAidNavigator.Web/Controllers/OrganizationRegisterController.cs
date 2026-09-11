using BCrypt.Net;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Models;
using SmartAidNavigator.Web.ViewModels;

namespace SmartAidNavigator.Web.Controllers;

public class OrganizationRegisterController : Controller
{
    private readonly AppDbContext _db;

    public OrganizationRegisterController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public IActionResult Ngo()
    {
        return View("Register", new OrganizationRegisterVm
        {
            RegisterType = "NGO"
        });
    }

    [HttpGet]
    public IActionResult Shelter()
    {
        return View("Register", new OrganizationRegisterVm
        {
            RegisterType = "SHELTER"
        });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Register(OrganizationRegisterVm vm)
    {
        vm.RegisterType = (vm.RegisterType ?? "").Trim().ToUpper();

        if (vm.RegisterType != "NGO" && vm.RegisterType != "SHELTER")
        {
            ModelState.AddModelError(nameof(vm.RegisterType), "Invalid registration type.");
        }

        if (vm.Latitude == null || vm.Longitude == null)
        {
            ModelState.AddModelError(nameof(vm.PlaceName), "Please select a valid Google location.");
        }

        if (vm.RegisterType == "SHELTER" && (!vm.Capacity.HasValue || vm.Capacity.Value <= 0))
        {
            ModelState.AddModelError(nameof(vm.Capacity), "Shelter capacity is required.");
        }

        if (!ModelState.IsValid)
        {
            return View(vm);
        }

        var email = vm.Email.Trim().ToLower();

        var emailExists = await _db.Persons
            .AnyAsync(x => x.Email != null && x.Email.ToLower() == email);

        if (emailExists)
        {
            ModelState.AddModelError(nameof(vm.Email), "This email is already registered.");
            return View(vm);
        }

        var roleName = vm.RegisterType == "NGO"
            ? "NGO_STAFF"
            : "SHELTER_MANAGER";

        var role = await _db.Roles.FirstOrDefaultAsync(x => x.RoleName == roleName);

        if (role == null)
        {
            ModelState.AddModelError("", $"Role {roleName} does not exist in roles table.");
            return View(vm);
        }

        using var tx = await _db.Database.BeginTransactionAsync();

        try
        {
            var person = new Person
            {
                FullName = vm.FullName.Trim(),
                IcOrPassport = string.IsNullOrWhiteSpace(vm.IcOrPassport) ? null : vm.IcOrPassport.Trim(),
                Email = email,
                Phone = vm.Phone.Trim(),
                AddressLine = vm.AddressLine,
                City = vm.City,
                State = vm.State,
                PostalCode = vm.PostalCode,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _db.Persons.Add(person);
            await _db.SaveChangesAsync();

            var user = new User
            {
                PersonId = person.PersonId,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(vm.Password),
                IsActive = false,
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

            if (vm.RegisterType == "NGO")
            {
                var ngo = new Ngo
                {
                    NgoName = vm.EntityName.Trim(),
                    Description = vm.Description,
                    Phone = vm.EntityPhone,
                    Email = vm.EntityEmail,
                    TaxExemptionNo = vm.TaxExemptionNo,
                    IsTaxExempt = vm.IsTaxExempt,
                    AddressLine = vm.AddressLine,
                    City = vm.City,
                    State = vm.State,
                    PostalCode = vm.PostalCode,
                    Latitude = vm.Latitude,
                    Longitude = vm.Longitude,
                    IsActive = false,
                    CreatedAt = DateTime.UtcNow
                };

                _db.Ngos.Add(ngo);
                await _db.SaveChangesAsync();

                _db.NgoStaff.Add(new NgoStaff
                {
                    NgoId = ngo.NgoId,
                    UserId = user.UserId,
                    StaffTitle = "Owner / Main Contact"
                });
            }
            else
            {
                var shelter = new Shelter
                {
                    ShelterName = vm.EntityName.Trim(),
                    Phone = vm.EntityPhone,
                    Email = vm.EntityEmail,
                    AddressLine = vm.AddressLine,
                    City = vm.City,
                    State = vm.State,
                    PostalCode = vm.PostalCode,
                    Latitude = vm.Latitude,
                    Longitude = vm.Longitude,
                    Capacity = vm.Capacity,
                    CurrentOccupancy = 0,
                    IsActive = false,
                    CreatedAt = DateTime.UtcNow
                };

                _db.Shelters.Add(shelter);
                await _db.SaveChangesAsync();

                _db.ShelterManagers.Add(new ShelterManager
                {
                    ShelterId = shelter.ShelterId,
                    UserId = user.UserId
                });
            }

            await _db.SaveChangesAsync();
            await tx.CommitAsync();

            TempData["RegisterSuccess"] =
                "Registration submitted successfully. Please wait for admin approval before logging in.";

            return RedirectToAction("Login", "Account");
        }
        catch
        {
            await tx.RollbackAsync();
            ModelState.AddModelError("", "Registration failed. Please check your details and try again.");
            return View(vm);
        }
    }
}