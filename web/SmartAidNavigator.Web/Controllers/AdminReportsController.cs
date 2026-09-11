using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Models;
using SmartAidNavigator.Web.Services;
using SmartAidNavigator.Web.ViewModels.Reports;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("ADMIN")]
public class AdminReportsController : Controller
{
    private readonly AppDbContext _db;
    private readonly ReportPdfService _pdf;

    public AdminReportsController(AppDbContext db, ReportPdfService pdf)
    {
        _db = db;
        _pdf = pdf;
    }

    public IActionResult Index()
    {
        return View();
    }

    public async Task<IActionResult> SystemSummary()
    {
        var vm = await BuildSystemSummaryReport();
        return View("ReportTable", vm);
    }

    public async Task<IActionResult> SystemSummaryPdf()
    {
        var vm = await BuildSystemSummaryReport();
        var bytes = _pdf.GenerateReportPdf(vm);
        return File(bytes, "application/pdf", "System_Summary_Report.pdf");
    }

    private async Task<ReportVm> BuildSystemSummaryReport()
    {
        var totalUsers = await _db.Users.CountAsync();
        var activeUsers = await _db.Users.CountAsync(x => x.IsActive);
        var ngos = await _db.Ngos.CountAsync();
        var activeNgos = await _db.Ngos.CountAsync(x => x.IsActive);
        var shelters = await _db.Shelters.CountAsync();
        var activeShelters = await _db.Shelters.CountAsync(x => x.IsActive);
        var beneficiaries = await _db.Beneficiaries.CountAsync();
        var donations = await _db.Donations.CountAsync();
        var deliveries = await _db.Deliveries.CountAsync();

        return new ReportVm
        {
            Title = "System Summary Report",
            Subtitle = "Overall system activity including users, NGOs, shelters, beneficiaries, donations, and deliveries.",
            RoleLabel = "Administrator",
            PdfAction = "SystemSummaryPdf",

            Stats =
            {
                new ReportStatVm { Label = "Users", Value = totalUsers.ToString(), Icon = "fa-solid fa-users", Color = "blue" },
                new ReportStatVm { Label = "NGOs", Value = activeNgos.ToString(), Icon = "fa-solid fa-building-ngo", Color = "purple" },
                new ReportStatVm { Label = "Shelters", Value = activeShelters.ToString(), Icon = "fa-solid fa-house-medical", Color = "teal" },
                new ReportStatVm { Label = "Deliveries", Value = deliveries.ToString(), Icon = "fa-solid fa-truck", Color = "orange" }
            },

            Columns = { "Category", "Total", "Active / Main Count", "Description" },

            Rows =
            {
                new List<string> { "Users", totalUsers.ToString(), activeUsers.ToString(), "Registered system user accounts." },
                new List<string> { "NGOs", ngos.ToString(), activeNgos.ToString(), "Registered NGO organizations." },
                new List<string> { "Shelters", shelters.ToString(), activeShelters.ToString(), "Registered shelter locations." },
                new List<string> { "Beneficiaries", beneficiaries.ToString(), beneficiaries.ToString(), "People registered under shelters." },
                new List<string> { "Donations", donations.ToString(), donations.ToString(), "Donation records submitted by public users." },
                new List<string> { "Deliveries", deliveries.ToString(), deliveries.ToString(), "Aid delivery records managed by NGOs." }
            }
        };
    }

    public async Task<IActionResult> ShelterCapacity()
    {
        var vm = await BuildShelterCapacityReport();
        return View("ReportTable", vm);
    }

    public async Task<IActionResult> ShelterCapacityPdf()
    {
        var vm = await BuildShelterCapacityReport();
        var bytes = _pdf.GenerateReportPdf(vm);
        return File(bytes, "application/pdf", "Shelter_Capacity_Report.pdf");
    }

    private async Task<ReportVm> BuildShelterCapacityReport()
    {
        var shelters = await _db.Shelters
            .Include(x => x.Ngo)
            .OrderBy(x => x.ShelterName)
            .ToListAsync();

        var totalCapacity = shelters.Sum(x => x.Capacity);
        var totalOccupancy = shelters.Sum(x => x.CurrentOccupancy);
        var available = totalCapacity - totalOccupancy;

        var vm = new ReportVm
        {
            Title = "Shelter Capacity Report",
            Subtitle = "Shelter occupancy, capacity usage, and available spaces.",
            RoleLabel = "Administrator",
            PdfAction = "ShelterCapacityPdf",

            Stats =
            {
                new ReportStatVm { Label = "Shelters", Value = shelters.Count.ToString(), Icon = "fa-solid fa-house-medical", Color = "blue" },
                new ReportStatVm { Label = "Capacity", Value = totalCapacity.ToString(), Icon = "fa-solid fa-bed", Color = "purple" },
                new ReportStatVm { Label = "Occupied", Value = totalOccupancy.ToString(), Icon = "fa-solid fa-people-group", Color = "orange" },
                new ReportStatVm { Label = "Available", Value = available.ToString(), Icon = "fa-solid fa-door-open", Color = "green" }
            },

            Columns = { "Shelter", "NGO", "City", "State", "Capacity", "Occupancy", "Available", "Usage" }
        };

        foreach (var s in shelters)
        {
            var remain = s.Capacity - s.CurrentOccupancy;
            var usage = s.Capacity > 0
                ? $"{((decimal)s.CurrentOccupancy / s.Capacity * 100):N1}%"
                : "0%";

            vm.Rows.Add(new List<string>
            {
                s.ShelterName,
                s.Ngo?.NgoName ?? "-",
                s.City ?? "-",
                s.State ?? "-",
                s.Capacity.ToString(),
                s.CurrentOccupancy.ToString(),
                remain.ToString(),
                usage
            });
        }

        return vm;
    }

    public async Task<IActionResult> Donation()
    {
        var vm = await BuildDonationReport();
        return View("ReportTable", vm);
    }

    public async Task<IActionResult> DonationPdf()
    {
        var vm = await BuildDonationReport();
        var bytes = _pdf.GenerateReportPdf(vm);
        return File(bytes, "application/pdf", "Donation_Report.pdf");
    }

    private async Task<ReportVm> BuildDonationReport()
    {
        var donations = await _db.Donations
            .Include(x => x.Ngo)
            .Include(x => x.Shelter)
            .Include(x => x.Donor)
                .ThenInclude(x => x!.Person)
            .Include(x => x.Payment)
            .OrderByDescending(x => x.CreatedAt)
            .ToListAsync();

        var vm = new ReportVm
        {
            Title = "Donation Report",
            Subtitle = "Donation records submitted by public users to NGOs and shelters.",
            RoleLabel = "Administrator",
            PdfAction = "DonationPdf",

            Stats =
            {
                new ReportStatVm { Label = "Total Donations", Value = donations.Count.ToString(), Icon = "fa-solid fa-hand-holding-dollar", Color = "blue" },
                new ReportStatVm { Label = "Pending", Value = donations.Count(x => x.Status == "PENDING").ToString(), Icon = "fa-solid fa-clock", Color = "orange" },
                new ReportStatVm { Label = "Completed", Value = donations.Count(x => x.Status == "COMPLETED").ToString(), Icon = "fa-solid fa-check", Color = "green" },
                new ReportStatVm { Label = "Money Total", Value = $"RM {donations.Sum(x => x.Payment?.Amount ?? 0):N2}", Icon = "fa-solid fa-money-bill", Color = "purple" }
            },

            Columns = { "ID", "Donor", "Type", "NGO", "Shelter", "Status", "Amount", "Created" }
        };

        foreach (var d in donations)
        {
            vm.Rows.Add(new List<string>
            {
                d.DonationId.ToString(),
                d.Donor?.Person?.FullName ?? "-",
                d.DonationType,
                d.Ngo?.NgoName ?? "-",
                d.Shelter?.ShelterName ?? "-",
                d.Status,
                d.Payment != null ? $"RM {d.Payment.Amount:N2}" : "-",
                d.CreatedAt.ToString("dd MMM yyyy")
            });
        }

        return vm;
    }

    public async Task<IActionResult> Delivery()
    {
        var vm = await BuildDeliveryReport();
        return View("ReportTable", vm);
    }

    public async Task<IActionResult> DeliveryPdf()
    {
        var vm = await BuildDeliveryReport();
        var bytes = _pdf.GenerateReportPdf(vm);
        return File(bytes, "application/pdf", "Delivery_Report.pdf");
    }

    private async Task<ReportVm> BuildDeliveryReport()
    {
        var deliveries = await _db.Deliveries
            .Include(x => x.Ngo)
            .Include(x => x.Shelter)
            .Include(x => x.DeliveryItems)
            .OrderByDescending(x => x.CreatedAt)
            .ToListAsync();

        var vm = new ReportVm
        {
            Title = "Delivery Report",
            Subtitle = "Overall delivery records, delivery status, distance, ETA, and item quantities.",
            RoleLabel = "Administrator",
            PdfAction = "DeliveryPdf",

            Stats =
            {
                new ReportStatVm { Label = "Deliveries", Value = deliveries.Count.ToString(), Icon = "fa-solid fa-truck", Color = "blue" },
                new ReportStatVm { Label = "In Transit", Value = deliveries.Count(x => x.Status == DeliveryStatus.IN_TRANSIT).ToString(), Icon = "fa-solid fa-truck-fast", Color = "orange" },
                new ReportStatVm { Label = "Delivered", Value = deliveries.Count(x => x.Status == DeliveryStatus.DELIVERED).ToString(), Icon = "fa-solid fa-check-double", Color = "green" },
                new ReportStatVm { Label = "Cancelled", Value = deliveries.Count(x => x.Status == DeliveryStatus.CANCELLED).ToString(), Icon = "fa-solid fa-ban", Color = "red" }
            },

            Columns = { "ID", "NGO", "Shelter", "Status", "Scheduled", "Distance", "ETA", "Items" }
        };

        foreach (var d in deliveries)
        {
            vm.Rows.Add(new List<string>
            {
                d.DeliveryId.ToString(),
                d.Ngo?.NgoName ?? "-",
                d.Shelter?.ShelterName ?? "-",
                d.Status.ToString(),
                d.ScheduledDate?.ToString("dd MMM yyyy") ?? "-",
                d.DistanceKm.HasValue ? $"{d.DistanceKm:N1} km" : "-",
                d.EtaMinutes.HasValue ? $"{d.EtaMinutes} min" : "-",
                d.DeliveryItems.Sum(x => x.Quantity).ToString()
            });
        }

        return vm;
    }
}