using BCrypt.Net;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.Models;
using SmartAidNavigator.Web.ViewModels;

namespace SmartAidNavigator.Web.Controllers;

public class AccountController : Controller
{
    private readonly AppDbContext _db;
    public const string NgoId = "NGO_ID";
    public const string NgoName = "NGO_NAME";

    public AccountController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public IActionResult Login(string? returnUrl = null)
    {
        ViewBag.ReturnUrl = returnUrl;
        return View(new LoginViewModel());
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Login(LoginViewModel vm, string? returnUrl = null)
    {
        ViewBag.ReturnUrl = returnUrl;

        if (!ModelState.IsValid)
            return View(vm);

        var email = vm.Email.Trim().ToLower();

        var user = await _db.Users
            .Include(u => u.Person)
            .FirstOrDefaultAsync(u =>
                u.Person != null &&
                u.Person.Email != null &&
                u.Person.Email.ToLower() == email);

        if (user == null)
        {
            vm.ErrorMessage = "Invalid email or password.";
            return View(vm);
        }

        // Verify password using BCrypt
        var ok = BCrypt.Net.BCrypt.Verify(vm.Password, user.PasswordHash);
        if (!ok)
        {
            vm.ErrorMessage = "Invalid email or password.";
            return View(vm);
        }

        // Block pending/deactivated account before creating session
        if (!user.IsActive)
        {
            var ngo = await _db.NgoStaff
                .Where(x => x.UserId == user.UserId)
                .Join(
                    _db.Ngos,
                    staff => staff.NgoId,
                    ngo => ngo.NgoId,
                    (staff, ngo) => ngo
                )
                .FirstOrDefaultAsync();

            if (ngo != null)
            {
                if (ngo.ApprovedAt != null)
                {
                    vm.ErrorMessage = "This NGO account has been deactivated by admin. Please contact the system administrator if you believe this is a mistake.";
                }
                else
                {
                    vm.ErrorMessage = "Your NGO registration request is still pending admin approval.";
                }

                return View(vm);
            }

            var shelter = await _db.ShelterManagers
                .Where(x => x.UserId == user.UserId)
                .Join(
                    _db.Shelters,
                    manager => manager.ShelterId,
                    shelter => shelter.ShelterId,
                    (manager, shelter) => shelter
                )
                .FirstOrDefaultAsync();

            if (shelter != null)
            {
                if (shelter.ApprovedAt != null)
                {
                    vm.ErrorMessage = "This shelter manager account has been deactivated by admin. Please contact the system administrator if you believe this is a mistake.";
                }
                else
                {
                    vm.ErrorMessage = "Your shelter registration request is still pending admin approval.";
                }

                return View(vm);
            }

            vm.ErrorMessage = "Your account is inactive. Please contact the system administrator.";
            return View(vm);
        }

        // Load roles (join user_roles -> roles)
        var roles = await (from ur in _db.UserRoles
                           join r in _db.Roles on ur.RoleId equals r.RoleId
                           where ur.UserId == user.UserId
                           select r.RoleName)
                          .Distinct()
                          .ToListAsync();

        // store in session
        HttpContext.Session.SetString(SessionKeys.UserId, user.UserId.ToString());
        HttpContext.Session.SetString(SessionKeys.Email, user.Person?.Email ?? "");
        HttpContext.Session.SetString(SessionKeys.FullName, user.Person?.FullName ?? "User");
        HttpContext.Session.SetString(SessionKeys.Roles, string.Join(",", roles));

        // NGO mapping (from ngo_staff)
        var ngoInfo = await (from ns in _db.NgoStaff
                             join n in _db.Ngos on ns.NgoId equals n.NgoId
                             where ns.UserId == user.UserId
                             select new { n.NgoId, n.NgoName })
                            .FirstOrDefaultAsync();

        HttpContext.Session.SetString(SessionKeys.NgoId, ngoInfo?.NgoId.ToString() ?? "");
        HttpContext.Session.SetString(SessionKeys.NgoName, ngoInfo?.NgoName ?? "");

        // Redirect
        if (!string.IsNullOrWhiteSpace(returnUrl) && Url.IsLocalUrl(returnUrl))
            return Redirect(returnUrl);

        var rolesCsv = HttpContext.Session.GetString(SessionKeys.Roles) ?? "";

        if (rolesCsv.Contains("ADMIN"))
            return RedirectToAction("Dashboard", "Admin");

        if (rolesCsv.Contains("NGO_STAFF"))
            return RedirectToAction("Dashboard", "NgoStaff");

        if (rolesCsv.Contains("SHELTER_MANAGER"))
            return RedirectToAction("Dashboard", "ShelterManager");

        return RedirectToAction("Index", "Home");
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public IActionResult Logout()
    {
        HttpContext.Session.Clear();
        return RedirectToAction("Login", "Account");
    }
}
