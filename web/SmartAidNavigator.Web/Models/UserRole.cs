using Microsoft.AspNetCore.Mvc;

namespace SmartAidNavigator.Web.Models;

public class UserRole
{
    public long UserId { get; set; }
    public int RoleId { get; set; }

    public User? User { get; set; }
    public Role? Role { get; set; }
}

