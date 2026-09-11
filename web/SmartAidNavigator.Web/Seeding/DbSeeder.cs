using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Models;

namespace SmartAidNavigator.Web.Seeding;

public static class DbSeeder
{
    public static async Task SeedRolesAndAdminAsync(AppDbContext db, IConfiguration config)
    {
        // Ensure roles exist (safe even if your SQL already inserted them)
        var requiredRoles = new[] { "ADMIN", "NGO_STAFF", "SHELTER_MANAGER" };

        foreach (var roleName in requiredRoles)
        {
            var exists = await db.Roles.AnyAsync(r => r.RoleName == roleName);
            if (!exists)
            {
                db.Roles.Add(new Role { RoleName = roleName });
            }
        }
        await db.SaveChangesAsync();

        // Seed 1 admin user if not exists
        var adminEmail = (config["SeedAdmin:Email"] ?? "admin@yknow.com").Trim();
        var adminPassword = config["SeedAdmin:Password"] ?? "Admin@123";
        var adminFullName = config["SeedAdmin:FullName"] ?? "System Admin";

        var adminUser = await db.Users
            .Include(u => u.Person)
            .FirstOrDefaultAsync(u => u.Person != null && u.Person.Email == adminEmail);
        if (adminUser == null)
        {
            var adminPerson = new Person
            {
                FullName = adminFullName,
                Email = adminEmail,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            db.Persons.Add(adminPerson);
            await db.SaveChangesAsync();

            adminUser = new User
            {
                PersonId = adminPerson.PersonId,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(adminPassword),
                IsActive = true,
                IsGuest = false,
                CreatedAt = DateTime.UtcNow
            };

            db.Users.Add(adminUser);
            await db.SaveChangesAsync();
        }

        // Ensure admin has ADMIN role
        var adminRoleId = await db.Roles
            .Where(r => r.RoleName == "ADMIN")
            .Select(r => r.RoleId)
            .FirstAsync();

        var hasAdminRole = await db.UserRoles.AnyAsync(ur =>
            ur.UserId == adminUser.UserId && ur.RoleId == adminRoleId);

        if (!hasAdminRole)
        {
            db.UserRoles.Add(new UserRole
            {
                UserId = adminUser.UserId,
                RoleId = adminRoleId
            });
            await db.SaveChangesAsync();
        }
    }
}
