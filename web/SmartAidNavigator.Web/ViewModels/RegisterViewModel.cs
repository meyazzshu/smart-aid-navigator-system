using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.ViewModels;

public class RegisterViewModel
{
    [Required, MaxLength(120)]
    public string FullName { get; set; } = "";

    [Required, EmailAddress, MaxLength(190)]
    public string Email { get; set; } = "";

    [Required, MinLength(6)]
    public string Password { get; set; } = "";

    // allow only NGO_STAFF or SHELTER_MANAGER from UI
    [Required]
    public string RoleName { get; set; } = "";
}
