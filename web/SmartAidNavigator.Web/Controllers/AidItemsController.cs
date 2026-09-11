using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Models;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("ADMIN")]
public class AidItemsController : Controller
{
    private readonly AppDbContext _db;
    public AidItemsController(AppDbContext db) => _db = db;

    private async Task LoadCategoriesAsync(int? selectedCategoryId = null)
    {
        var cats = await _db.AidCategories
            .OrderBy(c => c.CategoryName)
            .ToListAsync();

        ViewBag.Categories = new SelectList(cats, "CategoryId", "CategoryName", selectedCategoryId);
    }

    public async Task<IActionResult> Index()
    {
        var list = await _db.AidItems
            .Include(i => i.Category)
            .OrderBy(i => i.Category.CategoryName)
            .ThenBy(i => i.ItemName)
            .ToListAsync();

        return View(list);
    }

    public async Task<IActionResult> Details(long id)
    {
        var item = await _db.AidItems
            .Include(i => i.Category)
            .FirstOrDefaultAsync(i => i.ItemId == id);

        if (item == null) return NotFound();
        return View(item);
    }

    public async Task<IActionResult> Create()
    {
        await LoadCategoriesAsync();
        return View(new AidItem { Unit = "unit", IsActive = true });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(AidItem model)
    {
        await LoadCategoriesAsync(model.CategoryId);

        if (!ModelState.IsValid) return View(model);

        // matches UNIQUE(category_id, item_name)
        var exists = await _db.AidItems.AnyAsync(x => x.CategoryId == model.CategoryId && x.ItemName == model.ItemName);
        if (exists)
        {
            ModelState.AddModelError(nameof(model.ItemName), "Item name already exists in this category.");
            return View(model);
        }

        _db.AidItems.Add(model);
        await _db.SaveChangesAsync();
        return RedirectToAction(nameof(Index));
    }

    public async Task<IActionResult> Edit(long id)
    {
        var item = await _db.AidItems.FindAsync(id);
        if (item == null) return NotFound();

        await LoadCategoriesAsync(item.CategoryId);
        return View(item);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(long id, AidItem model)
    {
        if (id != model.ItemId) return BadRequest();

        await LoadCategoriesAsync(model.CategoryId);

        if (!ModelState.IsValid) return View(model);

        var exists = await _db.AidItems.AnyAsync(x =>
            x.CategoryId == model.CategoryId &&
            x.ItemName == model.ItemName &&
            x.ItemId != id);

        if (exists)
        {
            ModelState.AddModelError(nameof(model.ItemName), "Item name already exists in this category.");
            return View(model);
        }

        _db.Entry(model).State = EntityState.Modified;
        await _db.SaveChangesAsync();
        return RedirectToAction(nameof(Index));
    }

    public async Task<IActionResult> Delete(long id)
    {
        var item = await _db.AidItems
            .Include(i => i.Category)
            .FirstOrDefaultAsync(i => i.ItemId == id);

        if (item == null) return NotFound();
        return View(item);
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(long id)
    {
        var item = await _db.AidItems.FindAsync(id);
        if (item == null) return NotFound();

        _db.AidItems.Remove(item);
        await _db.SaveChangesAsync();
        return RedirectToAction(nameof(Index));
    }
}

