using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Models;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("ADMIN")]
public class AidCategoriesController : Controller
{
    private readonly AppDbContext _db;
    public AidCategoriesController(AppDbContext db) => _db = db;

    public async Task<IActionResult> Index()
    {
        var list = await _db.AidCategories
            .Include(x => x.Items)
            .OrderBy(x => x.CategoryName)
            .ToListAsync();

        return View(list);
    }

    public async Task<IActionResult> Details(int id)
    {
        var cat = await _db.AidCategories
            .Include(x => x.Items)
            .FirstOrDefaultAsync(x => x.CategoryId == id);

        if (cat == null) return NotFound();
        return View(cat);
    }

    public IActionResult Create() => View(new AidCategory());

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(AidCategory model)
    {
        if (!ModelState.IsValid) return View(model);

        var exists = await _db.AidCategories.AnyAsync(x => x.CategoryName == model.CategoryName);
        if (exists)
        {
            ModelState.AddModelError(nameof(model.CategoryName), "Category name already exists.");
            return View(model);
        }

        _db.AidCategories.Add(model);
        await _db.SaveChangesAsync();
        return RedirectToAction(nameof(Index));
    }

    public async Task<IActionResult> Edit(int id)
    {
        var cat = await _db.AidCategories.FindAsync(id);
        if (cat == null) return NotFound();
        return View(cat);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, AidCategory model)
    {
        if (id != model.CategoryId) return BadRequest();
        if (!ModelState.IsValid) return View(model);

        var exists = await _db.AidCategories.AnyAsync(x => x.CategoryName == model.CategoryName && x.CategoryId != id);
        if (exists)
        {
            ModelState.AddModelError(nameof(model.CategoryName), "Category name already exists.");
            return View(model);
        }

        _db.Entry(model).State = EntityState.Modified;
        await _db.SaveChangesAsync();
        return RedirectToAction(nameof(Index));
    }

    public async Task<IActionResult> Delete(int id)
    {
        var cat = await _db.AidCategories
            .FirstOrDefaultAsync(x => x.CategoryId == id);
        if (cat == null) return NotFound();
        return View(cat);
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(int id)
    {
        var cat = await _db.AidCategories
            .Include(x => x.Items)
            .FirstOrDefaultAsync(x => x.CategoryId == id);

        if (cat == null) return NotFound();

        // prevent deleting category that still has items
        if (cat.Items != null && cat.Items.Count > 0)
        {
            TempData["Error"] = "Cannot delete this category because it has items. Delete/move items first.";
            return RedirectToAction(nameof(Delete), new { id });
        }

        _db.AidCategories.Remove(cat);
        await _db.SaveChangesAsync();
        return RedirectToAction(nameof(Index));
    }
}
