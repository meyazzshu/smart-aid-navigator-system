using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Models;
using SmartAidNavigator.Web.ViewModels;

namespace SmartAidNavigator.Web.Controllers;

public class RegisterController : Controller
{
    private readonly AppDbContext _db;
    public RegisterController(AppDbContext db) => _db = db;

    [HttpGet]
    public IActionResult Index() => View(new RegisterViewModel());

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Index(RegisterViewModel vm)
    {
        // Security, do NOT allow self-register as ADMIN
        var allowed = new[] { "NGO_STAFF", "SHELTER_MANAGER" };
        if (!allowed.Contains(vm.RoleName))
            ModelState.AddModelError(nameof(vm.RoleName), "Invalid role selection.");

        if (!ModelState.IsValid)
            return View(vm);

        var email = vm.Email.Trim().ToLower();
        var exists = await _db.Persons.AnyAsync(p => p.Email != null && p.Email.ToLower() == email);
        if (exists)
        {
            ModelState.AddModelError(nameof(vm.Email), "Email already exists.");
            return View(vm);
        }

        var person = new Person
        {
            FullName = vm.FullName.Trim(),
            Email = email,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _db.Persons.Add(person);
        await _db.SaveChangesAsync();

        var user = new User
        {
            PersonId = person.PersonId,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(vm.Password),
            IsActive = true,
            IsGuest = false,
            CreatedAt = DateTime.UtcNow
        };

        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        var roleId = await _db.Roles
            .Where(r => r.RoleName == vm.RoleName)
            .Select(r => r.RoleId)
            .FirstAsync();

        _db.UserRoles.Add(new UserRole { UserId = user.UserId, RoleId = roleId });
        await _db.SaveChangesAsync();

        // go login
        return RedirectToAction("Login", "Account");
    }
}
