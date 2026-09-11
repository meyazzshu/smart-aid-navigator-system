namespace SmartAidNavigator.Web.Helpers;

public static class PersonHelper
{
    public static int? CalculateAge(DateOnly? dateOfBirth)
    {
        if (!dateOfBirth.HasValue) return null;
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var years = today.Year - dateOfBirth.Value.Year;
        if (today < dateOfBirth.Value.AddYears(years)) years--;
        return years;
    }

    public static bool IsChild(DateOnly? dateOfBirth)
    {
        var age = CalculateAge(dateOfBirth);
        return age.HasValue && age.Value < 18;
    }
}
