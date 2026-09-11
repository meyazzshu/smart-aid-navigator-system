using Microsoft.AspNetCore.Mvc;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.Models;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("SHELTER_MANAGER")]
public class ShelterOnboardingController : Controller
{
    private readonly AppDbContext _db;
    public ShelterOnboardingController(AppDbContext db) => _db = db;

    [HttpGet]
    public IActionResult Create() => View(new Shelter());

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(Shelter shelter)
    {
        if (!ModelState.IsValid) return View(shelter);

        var userIdStr = HttpContext.Session.GetString(SessionKeys.UserId);
        if (string.IsNullOrEmpty(userIdStr)) return RedirectToAction("Login", "Account");
        var userId = long.Parse(userIdStr);

        shelter.CreatedAt = DateTime.Now;
        shelter.IsActive = true;
        _db.Shelters.Add(shelter);
        await _db.SaveChangesAsync();

        _db.ShelterManagers.Add(new ShelterManager
        {
            ShelterId = shelter.ShelterId,
            UserId = userId
        });
        await _db.SaveChangesAsync();

        return RedirectToAction("Dashboard", "ShelterManager");
    }
}
