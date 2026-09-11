using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.Models;
using SmartAidNavigator.Web.Services;
using SmartAidNavigator.Web.ViewModels.Reports;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("NGO_STAFF")]
public class NgoReportsController : Controller
{
    private readonly AppDbContext _db;
    private readonly ReportPdfService _pdf;

    public NgoReportsController(AppDbContext db, ReportPdfService pdf)
    {
        _db = db;
        _pdf = pdf;
    }

    private async Task<long> GetMyNgoIdAsync()
    {
        var userIdStr = HttpContext.Session.GetString(SessionKeys.UserId);
        if (string.IsNullOrWhiteSpace(userIdStr)) return 0;

        var userId = long.Parse(userIdStr);

        var ngoStaff = await _db.NgoStaff
            .FirstOrDefaultAsync(x => x.UserId == userId);

        return ngoStaff?.NgoId ?? 0;
    }

    public IActionResult Index()
    {
        return View();
    }

    public async Task<IActionResult> DonationManagement()
    {
        var vm = await BuildDonationManagementReport();
        return View("ReportTable", vm);
    }

    public async Task<IActionResult> DonationManagementPdf()
    {
        var vm = await BuildDonationManagementReport();
        var bytes = _pdf.GenerateReportPdf(vm);
        return File(bytes, "application/pdf", "NGO_Donation_Management_Report.pdf");
    }

    private async Task<ReportVm> BuildDonationManagementReport()
    {
        var ngoId = await GetMyNgoIdAsync();

        var donations = await _db.Donations
            .Include(x => x.Donor)
                .ThenInclude(x => x!.Person)
            .Include(x => x.Payment)
            .Where(x => x.NgoId == ngoId)
            .OrderByDescending(x => x.CreatedAt)
            .ToListAsync();

        var vm = new ReportVm
        {
            Title = "Donation Management Report",
            Subtitle = "Donation records received and managed by your NGO.",
            RoleLabel = "NGO Staff",
            PdfAction = "DonationManagementPdf",

            Stats =
            {
                new ReportStatVm { Label = "Total", Value = donations.Count.ToString(), Icon = "fa-solid fa-hand-holding-dollar", Color = "blue" },
                new ReportStatVm { Label = "Pending", Value = donations.Count(x => x.Status == "PENDING").ToString(), Icon = "fa-solid fa-clock", Color = "orange" },
                new ReportStatVm { Label = "Confirmed", Value = donations.Count(x => x.Status == "CONFIRMED").ToString(), Icon = "fa-solid fa-circle-check", Color = "purple" },
                new ReportStatVm { Label = "Completed", Value = donations.Count(x => x.Status == "COMPLETED").ToString(), Icon = "fa-solid fa-check-double", Color = "green" }
            },

            Columns = { "Donation ID", "Donor", "Type", "Status", "Amount", "Created" }
        };

        foreach (var d in donations)
        {
            vm.Rows.Add(new List<string>
            {
                d.DonationId.ToString(),
                d.Donor?.Person?.FullName ?? "-",
                d.DonationType,
                d.Status,
                d.Payment != null ? $"RM {d.Payment.Amount:N2}" : "-",
                d.CreatedAt.ToString("dd MMM yyyy")
            });
        }

        return vm;
    }

    public async Task<IActionResult> AidDistribution()
    {
        var vm = await BuildAidDistributionReport();
        return View("ReportTable", vm);
    }

    public async Task<IActionResult> AidDistributionPdf()
    {
        var vm = await BuildAidDistributionReport();
        var bytes = _pdf.GenerateReportPdf(vm);
        return File(bytes, "application/pdf", "NGO_Aid_Distribution_Report.pdf");
    }

    private async Task<ReportVm> BuildAidDistributionReport()
    {
        var ngoId = await GetMyNgoIdAsync();

        var deliveries = await _db.Deliveries
            .Include(x => x.Shelter)
            .Include(x => x.DeliveryItems)
                .ThenInclude(x => x.Item)
            .Where(x => x.NgoId == ngoId)
            .OrderByDescending(x => x.CreatedAt)
            .ToListAsync();

        var distributed = deliveries
            .Where(x => x.Status == DeliveryStatus.DELIVERED)
            .ToList();

        var vm = new ReportVm
        {
            Title = "Aid Distribution Report",
            Subtitle = "Aid items distributed by your NGO to shelters.",
            RoleLabel = "NGO Staff",
            PdfAction = "AidDistributionPdf",

            Stats =
            {
                new ReportStatVm { Label = "Deliveries", Value = deliveries.Count.ToString(), Icon = "fa-solid fa-truck", Color = "blue" },
                new ReportStatVm { Label = "Delivered", Value = distributed.Count.ToString(), Icon = "fa-solid fa-check-double", Color = "green" },
                new ReportStatVm { Label = "Item Types", Value = distributed.Sum(x => x.DeliveryItems.Count).ToString(), Icon = "fa-solid fa-boxes-stacked", Color = "purple" },
                new ReportStatVm { Label = "Total Quantity", Value = distributed.Sum(x => x.DeliveryItems.Sum(i => i.Quantity)).ToString(), Icon = "fa-solid fa-cubes", Color = "orange" }
            },

            Columns = { "Delivery ID", "Shelter", "Status", "Scheduled", "Item", "Quantity", "Unit" }
        };

        foreach (var d in deliveries)
        {
            if (d.DeliveryItems.Any())
            {
                foreach (var item in d.DeliveryItems)
                {
                    vm.Rows.Add(new List<string>
                    {
                        d.DeliveryId.ToString(),
                        d.Shelter?.ShelterName ?? "-",
                        d.Status.ToString(),
                        d.ScheduledDate?.ToString("dd MMM yyyy") ?? "-",
                        item.Item?.ItemName ?? "-",
                        item.Quantity.ToString(),
                        item.Item?.Unit ?? "-"
                    });
                }
            }
            else
            {
                vm.Rows.Add(new List<string>
                {
                    d.DeliveryId.ToString(),
                    d.Shelter?.ShelterName ?? "-",
                    d.Status.ToString(),
                    d.ScheduledDate?.ToString("dd MMM yyyy") ?? "-",
                    "-",
                    "0",
                    "-"
                });
            }
        }

        return vm;
    }

    public async Task<IActionResult> DeliveryPerformance()
    {
        var vm = await BuildDeliveryPerformanceReport();
        return View("ReportTable", vm);
    }

    public async Task<IActionResult> DeliveryPerformancePdf()
    {
        var vm = await BuildDeliveryPerformanceReport();
        var bytes = _pdf.GenerateReportPdf(vm);
        return File(bytes, "application/pdf", "NGO_Delivery_Performance_Report.pdf");
    }

    private async Task<ReportVm> BuildDeliveryPerformanceReport()
    {
        var ngoId = await GetMyNgoIdAsync();

        var deliveries = await _db.Deliveries
            .Include(x => x.Shelter)
            .Include(x => x.DeliveryItems)
            .Where(x => x.NgoId == ngoId)
            .OrderByDescending(x => x.CreatedAt)
            .ToListAsync();

        var activeCount = deliveries.Count(x =>
            x.Status == DeliveryStatus.PLANNED ||
            x.Status == DeliveryStatus.ROUTED ||
            x.Status == DeliveryStatus.IN_TRANSIT);

        var vm = new ReportVm
        {
            Title = "Delivery Performance Report",
            Subtitle = "Delivery status performance and movement summary for your NGO.",
            RoleLabel = "NGO Staff",
            PdfAction = "DeliveryPerformancePdf",

            Stats =
            {
                new ReportStatVm { Label = "Total", Value = deliveries.Count.ToString(), Icon = "fa-solid fa-truck", Color = "blue" },
                new ReportStatVm { Label = "Active", Value = activeCount.ToString(), Icon = "fa-solid fa-route", Color = "orange" },
                new ReportStatVm { Label = "Delivered", Value = deliveries.Count(x => x.Status == DeliveryStatus.DELIVERED).ToString(), Icon = "fa-solid fa-check-double", Color = "green" },
                new ReportStatVm { Label = "Cancelled", Value = deliveries.Count(x => x.Status == DeliveryStatus.CANCELLED).ToString(), Icon = "fa-solid fa-ban", Color = "red" }
            },

            Columns = { "Delivery ID", "Shelter", "Status", "Scheduled", "Distance", "ETA", "Item Qty", "Created" }
        };

        foreach (var d in deliveries)
        {
            vm.Rows.Add(new List<string>
            {
                d.DeliveryId.ToString(),
                d.Shelter?.ShelterName ?? "-",
                d.Status.ToString(),
                d.ScheduledDate?.ToString("dd MMM yyyy") ?? "-",
                d.DistanceKm.HasValue ? $"{d.DistanceKm:N1} km" : "-",
                d.EtaMinutes.HasValue ? $"{d.EtaMinutes} min" : "-",
                d.DeliveryItems.Sum(x => x.Quantity).ToString(),
                d.CreatedAt.ToString("dd MMM yyyy")
            });
        }

        return vm;
    }

    public async Task<IActionResult> RoutePlanning()
    {
        var vm = await BuildRoutePlanningReport();
        return View("ReportTable", vm);
    }

    public async Task<IActionResult> RoutePlanningPdf()
    {
        var vm = await BuildRoutePlanningReport();
        var bytes = _pdf.GenerateReportPdf(vm);
        return File(bytes, "application/pdf", "NGO_Route_Planning_Report.pdf");
    }

    private async Task<ReportVm> BuildRoutePlanningReport()
    {
        var ngoId = await GetMyNgoIdAsync();

        var groups = await _db.DeliveryGroups
            .Where(x => x.NgoId == ngoId)
            .OrderByDescending(x => x.CreatedAt)
            .ToListAsync();

        var groupIds = groups.Select(x => x.DeliveryGroupId).ToList();

        var stopCounts = await _db.DeliveryGroupDeliveries
            .Where(x => groupIds.Contains(x.DeliveryGroupId))
            .GroupBy(x => x.DeliveryGroupId)
            .Select(g => new
            {
                DeliveryGroupId = g.Key,
                StopCount = g.Count()
            })
            .ToDictionaryAsync(x => x.DeliveryGroupId, x => x.StopCount);

        var vm = new ReportVm
        {
            Title = "Route Planning Report",
            Subtitle = "Group delivery route planning, optimization status, distance, ETA, and stop count.",
            RoleLabel = "NGO Staff",
            PdfAction = "RoutePlanningPdf",

            Stats =
            {
                new ReportStatVm { Label = "Groups", Value = groups.Count().ToString(), Icon = "fa-solid fa-layer-group", Color = "blue" },
                new ReportStatVm { Label = "Routed", Value = groups.Count(x => x.Status == DeliveryStatus.ROUTED).ToString(), Icon = "fa-solid fa-route", Color = "purple" },
                new ReportStatVm { Label = "In Transit", Value = groups.Count(x => x.Status == DeliveryStatus.IN_TRANSIT).ToString(), Icon = "fa-solid fa-truck-fast", Color = "orange" },
                new ReportStatVm { Label = "Delivered", Value = groups.Count(x => x.Status == DeliveryStatus.DELIVERED).ToString(), Icon = "fa-solid fa-check-double", Color = "green" }
            },

            Columns = { "Group ID", "Group Name", "Status", "Scheduled", "Stops", "Distance", "ETA", "Optimized At" }
        };

        foreach (var g in groups)
        {
            vm.Rows.Add(new List<string>
            {
                g.DeliveryGroupId.ToString(),
                g.GroupName,
                g.Status.ToString(),
                g.ScheduledDate?.ToString("dd MMM yyyy") ?? "-",
                (stopCounts.ContainsKey(g.DeliveryGroupId) ? stopCounts[g.DeliveryGroupId] : 0).ToString(),
                g.TotalDistanceKm.HasValue ? $"{g.TotalDistanceKm:N1} km" : "-",
                g.TotalEtaMinutes.HasValue ? $"{g.TotalEtaMinutes} min" : "-",
                g.OptimizedAt?.ToString("dd MMM yyyy HH:mm") ?? "-"
            });
        }

        return vm;
    }
}