using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.Models;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("NGO_STAFF")]
public class MyNgoController : Controller
{
    private readonly AppDbContext _db;
    public MyNgoController(AppDbContext db) => _db = db;

    private long GetUserId()
    {
        var s = HttpContext.Session.GetString(SessionKeys.UserId);
        if (string.IsNullOrEmpty(s)) throw new InvalidOperationException("Not logged in.");
        return long.Parse(s);
    }

    private async Task<long?> GetMyNgoIdAsync(long userId)
    {
        return await _db.NgoStaff
            .Where(x => x.UserId == userId)
            .Select(x => (long?)x.NgoId)
            .FirstOrDefaultAsync();
    }

    [HttpGet]
    public async Task<IActionResult> Details()
    {
        var userId = GetUserId();
        var ngoId = await GetMyNgoIdAsync(userId);
        if (ngoId == null) return RedirectToAction("Create", "NgoOnboarding");

        var ngo = await _db.Ngos.FirstOrDefaultAsync(n => n.NgoId == ngoId.Value);
        if (ngo == null) return RedirectToAction("Create", "NgoOnboarding");

        return View(ngo);
    }

    [HttpGet]
    public async Task<IActionResult> Edit()
    {
        var userId = GetUserId();
        var ngoId = await GetMyNgoIdAsync(userId);
        if (ngoId == null) return RedirectToAction("Create", "NgoOnboarding");

        var ngo = await _db.Ngos.FirstOrDefaultAsync(n => n.NgoId == ngoId.Value);
        if (ngo == null) return RedirectToAction("Create", "NgoOnboarding");

        return View(ngo);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(Ngo ngo)
    {
        var userId = GetUserId();
        var ngoId = await GetMyNgoIdAsync(userId);
        if (ngoId == null) return Forbid();

        // prevent editing other NGO
        if (ngo.NgoId != ngoId.Value) return Forbid();

        if (!ModelState.IsValid) return View(ngo);

        _db.Entry(ngo).State = EntityState.Modified;
        await _db.SaveChangesAsync();

        return RedirectToAction(nameof(Details));
    }
}
