using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.Models;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("NGO_STAFF")]
public class NgoOnboardingController : Controller
{
    private readonly AppDbContext _db;
    public NgoOnboardingController(AppDbContext db) => _db = db;

    [HttpGet]
    public IActionResult Create() => View(new Ngo());

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(Ngo ngo)
    {
        if (!ModelState.IsValid) return View(ngo);

        var userIdStr = HttpContext.Session.GetString(SessionKeys.UserId);
        if (string.IsNullOrEmpty(userIdStr)) return RedirectToAction("Login", "Account");
        var userId = long.Parse(userIdStr);

        // create NGO
        ngo.CreatedAt = DateTime.UtcNow;
        ngo.IsActive = true;
        _db.Ngos.Add(ngo);
        await _db.SaveChangesAsync();

        // link this user as NGO_STAFF to newly created NGO
        _db.NgoStaff.Add(new NgoStaff
        {
            NgoId = ngo.NgoId,
            UserId = userId,
            StaffTitle = "Owner"
        });
        await _db.SaveChangesAsync();

        return RedirectToAction("Dashboard", "NgoStaff");
    }
}

