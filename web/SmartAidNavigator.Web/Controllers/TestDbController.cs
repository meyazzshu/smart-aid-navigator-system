using Microsoft.AspNetCore.Mvc;
using SmartAidNavigator.Web.Data;
using Microsoft.EntityFrameworkCore;

namespace SmartAidNavigator.Web.Controllers;

public class TestDbController : Controller
{
    private readonly AppDbContext _db;
    public TestDbController(AppDbContext db) => _db = db;

    public async Task<IActionResult> Index()
    {
        var userCount = await _db.Users.CountAsync();
        return Content($"DB Connected ✅ Users count: {userCount}");
    }
}
