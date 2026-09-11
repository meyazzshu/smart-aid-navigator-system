using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Helpers;

namespace SmartAidNavigator.Web.Helpers;

public static class CurrentUserHelper
{
    public static long GetUserId(HttpContext http)
    {
        var s = http.Session.GetString(SessionKeys.UserId);
        if (string.IsNullOrEmpty(s)) throw new InvalidOperationException("Not logged in.");
        return long.Parse(s);
    }

    public static async Task<long> GetMyShelterIdAsync(HttpContext http, AppDbContext db)
    {
        var userId = GetUserId(http);

        var shelterId = await db.ShelterManagers
            .Where(x => x.UserId == userId)
            .Select(x => (long?)x.ShelterId)
            .FirstOrDefaultAsync();

        if (shelterId == null)
            throw new InvalidOperationException("No shelter assigned. Complete onboarding.");

        return shelterId.Value;
    }

    public static async Task<long> GetMyNgoIdAsync(HttpContext http, AppDbContext db)
    {
        var userId = GetUserId(http);

        var ngoId = await db.NgoStaff
            .Where(x => x.UserId == userId)
            .Select(x => (long?)x.NgoId)
            .FirstOrDefaultAsync();

        if (ngoId == null)
            throw new InvalidOperationException("No NGO assigned. Complete onboarding.");

        return ngoId.Value;
    }
}
