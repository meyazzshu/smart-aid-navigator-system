using SmartAidNavigator.Web.Models;

namespace SmartAidNavigator.Web.ViewModels;

public class BeneficiaryIndexVm
{
    public string? Search { get; set; }
    public string? Gender { get; set; }
    public string? AgeGroup { get; set; }
    public string? Status { get; set; }
    public string? SortBy { get; set; }

    public int TotalCount { get; set; }
    public int ActiveCount { get; set; }
    public int DischargedCount { get; set; }
    public int MaleCount { get; set; }
    public int FemaleCount { get; set; }

    public List<Beneficiary> Rows { get; set; } = new();
}