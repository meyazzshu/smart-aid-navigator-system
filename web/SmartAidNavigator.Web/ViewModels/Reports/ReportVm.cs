namespace SmartAidNavigator.Web.ViewModels.Reports;

public class ReportVm
{
    public string Title { get; set; } = "";
    public string Subtitle { get; set; } = "";
    public string RoleLabel { get; set; } = "";
    public DateTime GeneratedAt { get; set; } = DateTime.Now;

    public List<ReportStatVm> Stats { get; set; } = new();
    public List<string> Columns { get; set; } = new();
    public List<List<string>> Rows { get; set; } = new();

    public string PdfAction { get; set; } = "";
    public string BackAction { get; set; } = "Index";
}

public class ReportStatVm
{
    public string Label { get; set; } = "";
    public string Value { get; set; } = "";
    public string Icon { get; set; } = "fa-solid fa-chart-simple";
    public string Color { get; set; } = "blue";
}