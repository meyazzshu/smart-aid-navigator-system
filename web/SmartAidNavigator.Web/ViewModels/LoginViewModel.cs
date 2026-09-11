using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.ViewModels;

public class LoginViewModel
{
    [Required, EmailAddress, MaxLength(190)]
    public string Email { get; set; } = "";

    [Required, DataType(DataType.Password)]
    public string Password { get; set; } = "";

    public string? ErrorMessage { get; set; }
}
